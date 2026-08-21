`timescale 1ns / 1ps

module tb_uart ();

    parameter BAUD_TICK = (100_000_000 / 9600) * 10;

    reg  clk;
    reg  reset;
    reg  rx;
    wire tx;

    integer i = 0, j = 0;
    reg [7:0] receive_data;
    reg [7:0] send_data;


    top dut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .tx(tx)
    );



    always #5 clk = ~clk;


    task WAIT_TX_DONE();
        wait (dut.U_UART_TX.tx_done);
    endtask



    task SENDER_FOR_UART_RX();
        begin
            // START
            rx = 0;
            #(BAUD_TICK);
            // data
            for (i = 0; i < 8; i = i + 1) begin
                rx = send_data[i];
                #(BAUD_TICK);
            end
            rx = 1;
            #(BAUD_TICK);
        end
    endtask

    //pc uart receiver
    task RECEIVER();
        begin
            // 
            wait (~tx);
            #(BAUD_TICK / 2);
            if (tx) $display("%tstart bit eror", $time);
            for (j = 0; j < 8; j = j + 1) begin
                #(BAUD_TICK);
                receive_data[j] = tx;
            end
            #(BAUD_TICK);
            if (~tx) $display("%t : stop bit error", $time);
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        rx = 1;

        #10;
        reset = 0;
        #10;

        //simulation for UART_RX
        send_data = 8'h31;
        SENDER_FOR_UART_RX();
        RECEIVER();
        if (send_data == receive_data) $display("%t : PASS !!", $time);
        else
            $display(
                "%t: FAIL !!, send_data = %d, recevied_data  %d",
                $time,
                send_data,
                receive_data
            );
        //#(BAUD_TICK*12);

        #100;
        $stop;
    end
endmodule
