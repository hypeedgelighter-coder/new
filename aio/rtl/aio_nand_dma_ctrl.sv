`timescale 1ns/1ps

// AIO portfolio project: APB3-controlled NAND page DMA engine.
//
// This is a controller-core model, deliberately separated from a technology-
// specific ONFI/Toggle PHY.  Its NAND side is a ready/valid transaction port;
// a real product can replace the simulation NAND model with a PHY wrapper.
module aio_nand_dma_ctrl #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer MAX_PAGE_WORDS = 64,
    parameter integer WORD_COUNT_WIDTH = 16
) (
    input  logic                  pclk,
    input  logic                  presetn,

    // APB3 slave
    input  logic                  psel,
    input  logic                  penable,
    input  logic                  pwrite,
    input  logic [11:0]           paddr,
    input  logic [31:0]           pwdata,
    output logic [31:0]           prdata,
    output logic                  pready,
    output logic                  pslverr,
    output logic                  irq,

    // Simple single-outstanding memory master (DMA side)
    output logic                  mem_req_valid,
    input  logic                  mem_req_ready,
    output logic                  mem_req_write,
    output logic [ADDR_WIDTH-1:0] mem_req_addr,
    output logic [31:0]           mem_req_wdata,
    output logic [3:0]            mem_req_wstrb,
    input  logic                  mem_rsp_valid,
    input  logic [31:0]           mem_rsp_rdata,
    output logic                  mem_rsp_ready,

    // Abstract NAND transaction port
    output logic                  nand_cmd_valid,
    input  logic                  nand_cmd_ready,
    output logic [1:0]            nand_cmd,
    output logic [23:0]           nand_row,
    output logic [WORD_COUNT_WIDTH-1:0] nand_words,

    output logic                  nand_w_valid,
    input  logic                  nand_w_ready,
    output logic [31:0]           nand_w_data,
    output logic [6:0]            nand_w_ecc,
    output logic                  nand_w_last,

    input  logic                  nand_r_valid,
    output logic                  nand_r_ready,
    input  logic [31:0]           nand_r_data,
    input  logic [6:0]            nand_r_ecc,
    input  logic                  nand_r_last,

    input  logic                  nand_done,
    input  logic                  nand_fail
);
    localparam logic [1:0] OP_PROGRAM = 2'd0;
    localparam logic [1:0] OP_READ    = 2'd1;
    localparam logic [1:0] OP_ERASE   = 2'd2;

    localparam logic [7:0] ERR_NONE        = 8'h00;
    localparam logic [7:0] ERR_BAD_LENGTH  = 8'h01;
    localparam logic [7:0] ERR_NAND_FAIL   = 8'h02;
    localparam logic [7:0] ERR_TIMEOUT     = 8'h03;
    localparam logic [7:0] ERR_ECC         = 8'h04;

    localparam logic [11:0] REG_CONTROL    = 12'h000;
    localparam logic [11:0] REG_STATUS     = 12'h004;
    localparam logic [11:0] REG_NAND_ROW   = 12'h008;
    localparam logic [11:0] REG_HOST_ADDR  = 12'h00c;
    localparam logic [11:0] REG_PAGE_WORDS = 12'h010;
    localparam logic [11:0] REG_TIMEOUT    = 12'h014;
    localparam logic [11:0] REG_CORR_COUNT = 12'h018;
    localparam logic [11:0] REG_UNCORR_COUNT=12'h01c;
    localparam logic [11:0] REG_ERROR_CODE = 12'h020;
    localparam logic [11:0] REG_IRQ_ENABLE = 12'h024;
    localparam logic [11:0] REG_ID         = 12'h0fc;

    typedef enum logic [3:0] {
        ST_IDLE, ST_DMA_READ_REQ, ST_DMA_READ_RSP, ST_NAND_CMD,
        ST_NAND_PROGRAM, ST_NAND_WAIT, ST_NAND_READ,
        ST_DMA_WRITE, ST_COMPLETE, ST_ERROR
    } state_t;

    state_t state;
    logic [31:0] page_data [0:MAX_PAGE_WORDS-1];
    logic [6:0]  page_ecc  [0:MAX_PAGE_WORDS-1];

    logic [1:0] op_reg;
    logic [23:0] row_reg;
    logic [ADDR_WIDTH-1:0] host_addr_reg;
    logic [WORD_COUNT_WIDTH-1:0] page_words_reg;
    logic [31:0] timeout_reg;
    logic irq_enable_reg;

    logic [1:0] active_op;
    logic [23:0] active_row;
    logic [ADDR_WIDTH-1:0] active_host_addr;
    logic [WORD_COUNT_WIDTH-1:0] active_words;
    logic [31:0] active_timeout;
    logic [WORD_COUNT_WIDTH-1:0] word_index;
    logic [31:0] timeout_count;
    logic [15:0] corrected_count;
    logic [15:0] uncorrectable_count;
    logic [7:0] error_code;
    logic done_sticky;
    logic error_sticky;
    logic uncorrectable_sticky;
    logic start_pulse;
    logic clear_status_pulse;
    logic apb_access;

    logic [6:0]  ecc_encode;
    logic [31:0] ecc_corrected_data;
    logic [1:0]  ecc_status;
    logic [5:0]  ecc_syndrome;

    secded_ecc_32 u_ecc (
        .data_i          (mem_rsp_rdata),
        .ecc_o           (ecc_encode),
        .check_data_i    (nand_r_data),
        .check_ecc_i     (nand_r_ecc),
        .corrected_data_o(ecc_corrected_data),
        .status_o        (ecc_status),
        .syndrome_o      (ecc_syndrome)
    );

    assign apb_access = psel && penable;
    assign pready = 1'b1;
    assign pslverr = apb_access &&
        !((paddr == REG_CONTROL) || (paddr == REG_STATUS) ||
          (paddr == REG_NAND_ROW) || (paddr == REG_HOST_ADDR) ||
          (paddr == REG_PAGE_WORDS) || (paddr == REG_TIMEOUT) ||
          (paddr == REG_CORR_COUNT) || (paddr == REG_UNCORR_COUNT) ||
          (paddr == REG_ERROR_CODE) || (paddr == REG_IRQ_ENABLE) ||
          (paddr == REG_ID));
    assign irq = irq_enable_reg && (done_sticky || error_sticky);

    always_comb begin
        prdata = 32'h0;
        case (paddr)
            REG_CONTROL:     prdata = {29'h0, op_reg, 1'b0};
            REG_STATUS:      prdata = {27'h0, uncorrectable_sticky,
                                       error_sticky, irq, done_sticky,
                                       (state != ST_IDLE)};
            REG_NAND_ROW:    prdata = {8'h0, row_reg};
            REG_HOST_ADDR:   prdata = host_addr_reg;
            REG_PAGE_WORDS:  prdata = {{(32-WORD_COUNT_WIDTH){1'b0}}, page_words_reg};
            REG_TIMEOUT:     prdata = timeout_reg;
            REG_CORR_COUNT:  prdata = {16'h0, corrected_count};
            REG_UNCORR_COUNT:prdata = {16'h0, uncorrectable_count};
            REG_ERROR_CODE:  prdata = {24'h0, error_code};
            REG_IRQ_ENABLE:  prdata = {31'h0, irq_enable_reg};
            REG_ID:          prdata = 32'h4149_4f31; // "AIO1"
            default:         prdata = 32'h0;
        endcase
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            op_reg <= OP_PROGRAM;
            row_reg <= '0;
            host_addr_reg <= '0;
            page_words_reg <= 16'd16;
            timeout_reg <= 32'd1024;
            irq_enable_reg <= 1'b0;
            start_pulse <= 1'b0;
            clear_status_pulse <= 1'b0;
        end else begin
            start_pulse <= 1'b0;
            clear_status_pulse <= 1'b0;
            if (apb_access && pwrite && !pslverr) begin
                case (paddr)
                    REG_CONTROL: begin
                        op_reg <= pwdata[2:1];
                        start_pulse <= pwdata[0];
                        clear_status_pulse <= pwdata[8];
                    end
                    REG_NAND_ROW:   row_reg <= pwdata[23:0];
                    REG_HOST_ADDR:  host_addr_reg <= pwdata[ADDR_WIDTH-1:0];
                    REG_PAGE_WORDS: page_words_reg <= pwdata[WORD_COUNT_WIDTH-1:0];
                    REG_TIMEOUT:    timeout_reg <= pwdata;
                    REG_IRQ_ENABLE: irq_enable_reg <= pwdata[0];
                    default: ;
                endcase
            end
        end
    end

    always_comb begin
        mem_req_valid = 1'b0;
        mem_req_write = 1'b0;
        mem_req_addr = active_host_addr + (word_index << 2);
        mem_req_wdata = page_data[word_index];
        mem_req_wstrb = 4'hf;
        mem_rsp_ready = 1'b0;

        nand_cmd_valid = 1'b0;
        nand_cmd = active_op;
        nand_row = active_row;
        nand_words = active_words;
        nand_w_valid = 1'b0;
        nand_w_data = page_data[word_index];
        nand_w_ecc = page_ecc[word_index];
        nand_w_last = (word_index == (active_words - 1'b1));
        nand_r_ready = 1'b0;

        case (state)
            ST_DMA_READ_REQ: begin
                mem_req_valid = 1'b1;
                mem_req_write = 1'b0;
            end
            ST_DMA_READ_RSP: mem_rsp_ready = 1'b1;
            ST_NAND_CMD: nand_cmd_valid = 1'b1;
            ST_NAND_PROGRAM: nand_w_valid = 1'b1;
            ST_NAND_READ: nand_r_ready = 1'b1;
            ST_DMA_WRITE: begin
                mem_req_valid = 1'b1;
                mem_req_write = 1'b1;
            end
            default: ;
        endcase
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            state <= ST_IDLE;
            active_op <= OP_PROGRAM;
            active_row <= '0;
            active_host_addr <= '0;
            active_words <= '0;
            active_timeout <= '0;
            word_index <= '0;
            timeout_count <= '0;
            corrected_count <= '0;
            uncorrectable_count <= '0;
            error_code <= ERR_NONE;
            done_sticky <= 1'b0;
            error_sticky <= 1'b0;
            uncorrectable_sticky <= 1'b0;
        end else begin
            if (clear_status_pulse) begin
                done_sticky <= 1'b0;
                error_sticky <= 1'b0;
                uncorrectable_sticky <= 1'b0;
                corrected_count <= '0;
                uncorrectable_count <= '0;
                error_code <= ERR_NONE;
            end

            if (state != ST_IDLE) begin
                if (timeout_count < active_timeout)
                    timeout_count <= timeout_count + 1'b1;
                if ((active_timeout != 0) && (timeout_count >= active_timeout - 1'b1) &&
                    (state != ST_COMPLETE) && (state != ST_ERROR)) begin
                    error_code <= ERR_TIMEOUT;
                    error_sticky <= 1'b1;
                    state <= ST_ERROR;
                end
            end else begin
                timeout_count <= '0;
            end

            case (state)
                ST_IDLE: begin
                    if (start_pulse) begin
                        done_sticky <= 1'b0;
                        error_sticky <= 1'b0;
                        uncorrectable_sticky <= 1'b0;
                        corrected_count <= '0;
                        uncorrectable_count <= '0;
                        error_code <= ERR_NONE;
                        active_op <= op_reg;
                        active_row <= row_reg;
                        active_host_addr <= host_addr_reg;
                        active_words <= page_words_reg;
                        active_timeout <= timeout_reg;
                        word_index <= '0;
                        timeout_count <= '0;
                        if ((page_words_reg == 0) || (page_words_reg > MAX_PAGE_WORDS)) begin
                            error_code <= ERR_BAD_LENGTH;
                            error_sticky <= 1'b1;
                            state <= ST_ERROR;
                        end else if (op_reg == OP_PROGRAM) begin
                            state <= ST_DMA_READ_REQ;
                        end else begin
                            state <= ST_NAND_CMD;
                        end
                    end
                end

                ST_DMA_READ_REQ: begin
                    if (mem_req_valid && mem_req_ready)
                        state <= ST_DMA_READ_RSP;
                end

                ST_DMA_READ_RSP: begin
                    if (mem_rsp_valid && mem_rsp_ready) begin
                        page_data[word_index] <= mem_rsp_rdata;
                        page_ecc[word_index] <= ecc_encode;
                        if (word_index == active_words - 1'b1) begin
                            word_index <= '0;
                            state <= ST_NAND_CMD;
                        end else begin
                            word_index <= word_index + 1'b1;
                            state <= ST_DMA_READ_REQ;
                        end
                    end
                end

                ST_NAND_CMD: begin
                    if (nand_cmd_valid && nand_cmd_ready) begin
                        word_index <= '0;
                        if (active_op == OP_PROGRAM)
                            state <= ST_NAND_PROGRAM;
                        else if (active_op == OP_READ)
                            state <= ST_NAND_READ;
                        else
                            state <= ST_NAND_WAIT;
                    end
                end

                ST_NAND_PROGRAM: begin
                    if (nand_w_valid && nand_w_ready) begin
                        if (word_index == active_words - 1'b1) begin
                            word_index <= '0;
                            state <= ST_NAND_WAIT;
                        end else begin
                            word_index <= word_index + 1'b1;
                        end
                    end
                end

                ST_NAND_READ: begin
                    // The PHY may give up before any data arrives (R/B# never
                    // returned).  Without this branch a failed READ could only
                    // end through the watchdog.
                    if (nand_done && nand_fail) begin
                        error_code <= ERR_NAND_FAIL;
                        error_sticky <= 1'b1;
                        state <= ST_ERROR;
                    end else if (nand_r_valid && nand_r_ready) begin
                        page_data[word_index] <= ecc_corrected_data;
                        page_ecc[word_index] <= nand_r_ecc;
                        if ((ecc_status == 2'd1) || (ecc_status == 2'd2))
                            corrected_count <= corrected_count + 1'b1;
                        if (ecc_status == 2'd3) begin
                            uncorrectable_count <= uncorrectable_count + 1'b1;
                            uncorrectable_sticky <= 1'b1;
                            error_sticky <= 1'b1;
                            error_code <= ERR_ECC;
                        end
                        if (nand_r_last || (word_index == active_words - 1'b1)) begin
                            word_index <= '0;
                            state <= ST_NAND_WAIT;
                        end else begin
                            word_index <= word_index + 1'b1;
                        end
                    end
                end

                ST_NAND_WAIT: begin
                    if (nand_done) begin
                        if (nand_fail) begin
                            error_code <= ERR_NAND_FAIL;
                            error_sticky <= 1'b1;
                            state <= ST_ERROR;
                        end else if (active_op == OP_READ) begin
                            word_index <= '0;
                            state <= ST_DMA_WRITE;
                        end else begin
                            state <= ST_COMPLETE;
                        end
                    end
                end

                ST_DMA_WRITE: begin
                    if (mem_req_valid && mem_req_ready) begin
                        if (word_index == active_words - 1'b1) begin
                            word_index <= '0;
                            state <= ST_COMPLETE;
                        end else begin
                            word_index <= word_index + 1'b1;
                        end
                    end
                end

                ST_COMPLETE: begin
                    done_sticky <= 1'b1;
                    state <= ST_IDLE;
                end

                ST_ERROR: begin
                    done_sticky <= 1'b1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

`ifndef SYNTHESIS
    // Lightweight protocol guards.  These run in simulation without UVM.
    always_ff @(posedge pclk) begin
        if (presetn) begin
            if (nand_w_valid && nand_w_ready && nand_w_last)
                assert (word_index == active_words - 1'b1)
                    else $error("nand_w_last asserted on wrong word");
            if (start_pulse && (state != ST_IDLE))
                $warning("start ignored while controller is busy");
        end
    end
`endif
endmodule
