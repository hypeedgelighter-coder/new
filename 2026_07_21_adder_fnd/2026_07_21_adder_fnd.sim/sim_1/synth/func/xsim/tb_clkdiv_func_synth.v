// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2020.2 (win64) Build 3064766 Wed Nov 18 09:12:45 MST 2020
// Date        : Tue Jul 21 16:01:29 2026
// Host        : DESKTOP-7CFQ9ND running 64-bit major release  (build 9200)
// Command     : write_verilog -mode funcsim -nolib -force -file
//               D:/26ai_camp/2026_07_21_adder_fnd/2026_07_21_adder_fnd.sim/sim_1/synth/func/xsim/tb_clkdiv_func_synth.v
// Design      : adder_fnd
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a35tcpg236-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* NotValidForBitStream *)
module adder_fnd
   (clk,
    reset,
    a,
    b,
    fnd_com,
    fnd_data,
    c);
  input clk;
  input reset;
  input [7:0]a;
  input [7:0]b;
  output [3:0]fnd_com;
  output [7:0]fnd_data;
  output c;

  wire \U_ADDER/a2/c1 ;
  wire \U_ADDER/a2/c3 ;
  wire [7:0]a;
  wire [7:0]a_IBUF;
  wire [7:0]b;
  wire [7:0]b_IBUF;
  wire c;
  wire c_OBUF;
  wire clk;
  wire clk_IBUF;
  wire clk_IBUF_BUFG;
  wire [3:0]fnd_com;
  wire [3:0]fnd_com_OBUF;
  wire [7:0]fnd_data;
  wire [6:0]fnd_data_OBUF;
  wire \fnd_data_OBUF[6]_inst_i_10_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_12_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_16_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_17_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_18_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_19_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_21_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_7_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_9_n_0 ;
  wire reset;
  wire reset_IBUF;
  wire [7:2]s;
  wire [6:1]s__0;

  fnd_controller U_FND_CNTL
       (.AR(reset_IBUF),
        .CLK(clk_IBUF_BUFG),
        .\a[4] (s__0[4:3]),
        .a_IBUF(a_IBUF),
        .b_IBUF(b_IBUF),
        .c1(\U_ADDER/a2/c1 ),
        .fnd_com_OBUF(fnd_com_OBUF),
        .fnd_data_OBUF(fnd_data_OBUF),
        .\fnd_data_OBUF[0]_inst_i_1 (\fnd_data_OBUF[6]_inst_i_12_n_0 ),
        .\fnd_data_OBUF[0]_inst_i_1_0 (\fnd_data_OBUF[6]_inst_i_10_n_0 ),
        .\fnd_data_OBUF[0]_inst_i_1_1 (\fnd_data_OBUF[6]_inst_i_7_n_0 ),
        .\fnd_data_OBUF[0]_inst_i_1_2 (\fnd_data_OBUF[6]_inst_i_9_n_0 ),
        .\fnd_data_OBUF[6]_inst_i_3 (\fnd_data_OBUF[6]_inst_i_18_n_0 ),
        .\fnd_data_OBUF[6]_inst_i_3_0 (\fnd_data_OBUF[6]_inst_i_17_n_0 ),
        .\fnd_data_OBUF[6]_inst_i_3_1 (\fnd_data_OBUF[6]_inst_i_16_n_0 ),
        .\fnd_data_OBUF[6]_inst_i_5 (\fnd_data_OBUF[6]_inst_i_21_n_0 ),
        .s({s[7],s[5],s[2]}),
        .s__0(s__0[1]));
  IBUF \a_IBUF[0]_inst 
       (.I(a[0]),
        .O(a_IBUF[0]));
  IBUF \a_IBUF[1]_inst 
       (.I(a[1]),
        .O(a_IBUF[1]));
  IBUF \a_IBUF[2]_inst 
       (.I(a[2]),
        .O(a_IBUF[2]));
  IBUF \a_IBUF[3]_inst 
       (.I(a[3]),
        .O(a_IBUF[3]));
  IBUF \a_IBUF[4]_inst 
       (.I(a[4]),
        .O(a_IBUF[4]));
  IBUF \a_IBUF[5]_inst 
       (.I(a[5]),
        .O(a_IBUF[5]));
  IBUF \a_IBUF[6]_inst 
       (.I(a[6]),
        .O(a_IBUF[6]));
  IBUF \a_IBUF[7]_inst 
       (.I(a[7]),
        .O(a_IBUF[7]));
  IBUF \b_IBUF[0]_inst 
       (.I(b[0]),
        .O(b_IBUF[0]));
  IBUF \b_IBUF[1]_inst 
       (.I(b[1]),
        .O(b_IBUF[1]));
  IBUF \b_IBUF[2]_inst 
       (.I(b[2]),
        .O(b_IBUF[2]));
  IBUF \b_IBUF[3]_inst 
       (.I(b[3]),
        .O(b_IBUF[3]));
  IBUF \b_IBUF[4]_inst 
       (.I(b[4]),
        .O(b_IBUF[4]));
  IBUF \b_IBUF[5]_inst 
       (.I(b[5]),
        .O(b_IBUF[5]));
  IBUF \b_IBUF[6]_inst 
       (.I(b[6]),
        .O(b_IBUF[6]));
  IBUF \b_IBUF[7]_inst 
       (.I(b[7]),
        .O(b_IBUF[7]));
  OBUF c_OBUF_inst
       (.I(c_OBUF),
        .O(c));
  LUT3 #(
    .INIT(8'hE8)) 
    c_OBUF_inst_i_1
       (.I0(\U_ADDER/a2/c3 ),
        .I1(a_IBUF[7]),
        .I2(b_IBUF[7]),
        .O(c_OBUF));
  (* SOFT_HLUTNM = "soft_lutpair10" *) 
  LUT5 #(
    .INIT(32'hFFE8E800)) 
    c_OBUF_inst_i_2
       (.I0(b_IBUF[5]),
        .I1(a_IBUF[5]),
        .I2(\U_ADDER/a2/c1 ),
        .I3(a_IBUF[6]),
        .I4(b_IBUF[6]),
        .O(\U_ADDER/a2/c3 ));
  BUFG clk_IBUF_BUFG_inst
       (.I(clk_IBUF),
        .O(clk_IBUF_BUFG));
  IBUF clk_IBUF_inst
       (.I(clk),
        .O(clk_IBUF));
  OBUF \fnd_com_OBUF[0]_inst 
       (.I(fnd_com_OBUF[0]),
        .O(fnd_com[0]));
  OBUF \fnd_com_OBUF[1]_inst 
       (.I(fnd_com_OBUF[1]),
        .O(fnd_com[1]));
  OBUF \fnd_com_OBUF[2]_inst 
       (.I(fnd_com_OBUF[2]),
        .O(fnd_com[2]));
  OBUF \fnd_com_OBUF[3]_inst 
       (.I(fnd_com_OBUF[3]),
        .O(fnd_com[3]));
  OBUF \fnd_data_OBUF[0]_inst 
       (.I(fnd_data_OBUF[0]),
        .O(fnd_data[0]));
  OBUF \fnd_data_OBUF[1]_inst 
       (.I(fnd_data_OBUF[1]),
        .O(fnd_data[1]));
  OBUF \fnd_data_OBUF[2]_inst 
       (.I(fnd_data_OBUF[2]),
        .O(fnd_data[2]));
  OBUF \fnd_data_OBUF[3]_inst 
       (.I(fnd_data_OBUF[3]),
        .O(fnd_data[3]));
  OBUF \fnd_data_OBUF[4]_inst 
       (.I(fnd_data_OBUF[4]),
        .O(fnd_data[4]));
  OBUF \fnd_data_OBUF[5]_inst 
       (.I(fnd_data_OBUF[5]),
        .O(fnd_data[5]));
  OBUF \fnd_data_OBUF[6]_inst 
       (.I(fnd_data_OBUF[6]),
        .O(fnd_data[6]));
  LUT6 #(
    .INIT(64'h7E145614D795D781)) 
    \fnd_data_OBUF[6]_inst_i_10 
       (.I0(\fnd_data_OBUF[6]_inst_i_19_n_0 ),
        .I1(s__0[3]),
        .I2(\fnd_data_OBUF[6]_inst_i_17_n_0 ),
        .I3(\fnd_data_OBUF[6]_inst_i_12_n_0 ),
        .I4(s__0[1]),
        .I5(s[2]),
        .O(\fnd_data_OBUF[6]_inst_i_10_n_0 ));
  LUT6 #(
    .INIT(64'h1E8FF178180EE170)) 
    \fnd_data_OBUF[6]_inst_i_12 
       (.I0(s__0[3]),
        .I1(s[7]),
        .I2(s__0[6]),
        .I3(s[5]),
        .I4(s__0[4]),
        .I5(s[2]),
        .O(\fnd_data_OBUF[6]_inst_i_12_n_0 ));
  LUT6 #(
    .INIT(64'hFE9797FE00000000)) 
    \fnd_data_OBUF[6]_inst_i_16 
       (.I0(a_IBUF[5]),
        .I1(b_IBUF[5]),
        .I2(\U_ADDER/a2/c1 ),
        .I3(a_IBUF[6]),
        .I4(b_IBUF[6]),
        .I5(s[7]),
        .O(\fnd_data_OBUF[6]_inst_i_16_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair9" *) 
  LUT5 #(
    .INIT(32'h739C6318)) 
    \fnd_data_OBUF[6]_inst_i_17 
       (.I0(s__0[4]),
        .I1(s[5]),
        .I2(s__0[6]),
        .I3(s[7]),
        .I4(s__0[3]),
        .O(\fnd_data_OBUF[6]_inst_i_17_n_0 ));
  LUT4 #(
    .INIT(16'hC642)) 
    \fnd_data_OBUF[6]_inst_i_18 
       (.I0(s[7]),
        .I1(s__0[6]),
        .I2(s[5]),
        .I3(s__0[4]),
        .O(\fnd_data_OBUF[6]_inst_i_18_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair9" *) 
  LUT5 #(
    .INIT(32'h59966599)) 
    \fnd_data_OBUF[6]_inst_i_19 
       (.I0(s__0[3]),
        .I1(s__0[4]),
        .I2(s[5]),
        .I3(s__0[6]),
        .I4(s[7]),
        .O(\fnd_data_OBUF[6]_inst_i_19_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair10" *) 
  LUT5 #(
    .INIT(32'h99969666)) 
    \fnd_data_OBUF[6]_inst_i_20 
       (.I0(a_IBUF[6]),
        .I1(b_IBUF[6]),
        .I2(b_IBUF[5]),
        .I3(a_IBUF[5]),
        .I4(\U_ADDER/a2/c1 ),
        .O(s__0[6]));
  LUT6 #(
    .INIT(64'h00FFF00003FFE000)) 
    \fnd_data_OBUF[6]_inst_i_21 
       (.I0(s[2]),
        .I1(s__0[4]),
        .I2(s[5]),
        .I3(s__0[6]),
        .I4(s[7]),
        .I5(s__0[3]),
        .O(\fnd_data_OBUF[6]_inst_i_21_n_0 ));
  LUT5 #(
    .INIT(32'hD22D4BB4)) 
    \fnd_data_OBUF[6]_inst_i_7 
       (.I0(\fnd_data_OBUF[6]_inst_i_12_n_0 ),
        .I1(s__0[1]),
        .I2(\fnd_data_OBUF[6]_inst_i_17_n_0 ),
        .I3(s__0[3]),
        .I4(s[2]),
        .O(\fnd_data_OBUF[6]_inst_i_7_n_0 ));
  LUT4 #(
    .INIT(16'h8778)) 
    \fnd_data_OBUF[6]_inst_i_8 
       (.I0(b_IBUF[0]),
        .I1(a_IBUF[0]),
        .I2(a_IBUF[1]),
        .I3(b_IBUF[1]),
        .O(s__0[1]));
  LUT6 #(
    .INIT(64'h6A95956A956A6A95)) 
    \fnd_data_OBUF[6]_inst_i_9 
       (.I0(s[2]),
        .I1(b_IBUF[0]),
        .I2(a_IBUF[0]),
        .I3(a_IBUF[1]),
        .I4(b_IBUF[1]),
        .I5(\fnd_data_OBUF[6]_inst_i_12_n_0 ),
        .O(\fnd_data_OBUF[6]_inst_i_9_n_0 ));
  OBUF \fnd_data_OBUF[7]_inst 
       (.I(1'b1),
        .O(fnd_data[7]));
  IBUF reset_IBUF_inst
       (.I(reset),
        .O(reset_IBUF));
endmodule

module counter_4
   (fnd_data_OBUF,
    fnd_com_OBUF,
    \fnd_data_OBUF[0]_inst_i_1_0 ,
    \fnd_data_OBUF[0]_inst_i_1_1 ,
    s__0,
    \fnd_data_OBUF[0]_inst_i_1_2 ,
    \fnd_data_OBUF[6]_inst_i_3_0 ,
    \fnd_data_OBUF[6]_inst_i_3_1 ,
    \fnd_data_OBUF[6]_inst_i_3_2 ,
    \fnd_data_OBUF[6]_inst_i_5_0 ,
    \fnd_data_OBUF[6]_inst_i_5_1 ,
    CO,
    \fnd_data_OBUF[0]_inst_i_1_3 ,
    \fnd_data_OBUF[0]_inst_i_1_4 ,
    a_IBUF,
    b_IBUF,
    CLK,
    AR);
  output [6:0]fnd_data_OBUF;
  output [3:0]fnd_com_OBUF;
  input \fnd_data_OBUF[0]_inst_i_1_0 ;
  input \fnd_data_OBUF[0]_inst_i_1_1 ;
  input [0:0]s__0;
  input \fnd_data_OBUF[0]_inst_i_1_2 ;
  input \fnd_data_OBUF[6]_inst_i_3_0 ;
  input \fnd_data_OBUF[6]_inst_i_3_1 ;
  input \fnd_data_OBUF[6]_inst_i_3_2 ;
  input \fnd_data_OBUF[6]_inst_i_5_0 ;
  input \fnd_data_OBUF[6]_inst_i_5_1 ;
  input [0:0]CO;
  input \fnd_data_OBUF[0]_inst_i_1_3 ;
  input \fnd_data_OBUF[0]_inst_i_1_4 ;
  input [0:0]a_IBUF;
  input [0:0]b_IBUF;
  input CLK;
  input [0:0]AR;

  wire [0:0]AR;
  wire CLK;
  wire [0:0]CO;
  wire [0:0]a_IBUF;
  wire [0:0]b_IBUF;
  wire [3:0]fnd_com_OBUF;
  wire [6:0]fnd_data_OBUF;
  wire \fnd_data_OBUF[0]_inst_i_1_0 ;
  wire \fnd_data_OBUF[0]_inst_i_1_1 ;
  wire \fnd_data_OBUF[0]_inst_i_1_2 ;
  wire \fnd_data_OBUF[0]_inst_i_1_3 ;
  wire \fnd_data_OBUF[0]_inst_i_1_4 ;
  wire \fnd_data_OBUF[6]_inst_i_11_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_13_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_14_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_15_n_0 ;
  wire \fnd_data_OBUF[6]_inst_i_3_0 ;
  wire \fnd_data_OBUF[6]_inst_i_3_1 ;
  wire \fnd_data_OBUF[6]_inst_i_3_2 ;
  wire \fnd_data_OBUF[6]_inst_i_5_0 ;
  wire \fnd_data_OBUF[6]_inst_i_5_1 ;
  wire \fnd_data_OBUF[6]_inst_i_6_n_0 ;
  wire [1:0]p_0_in;
  wire [0:0]s__0;
  wire [3:0]w_bcd;
  wire [1:0]w_digit_sel;

  (* SOFT_HLUTNM = "soft_lutpair6" *) 
  LUT1 #(
    .INIT(2'h1)) 
    \counter_reg[0]_i_1 
       (.I0(w_digit_sel[0]),
        .O(p_0_in[0]));
  (* SOFT_HLUTNM = "soft_lutpair3" *) 
  LUT2 #(
    .INIT(4'h6)) 
    \counter_reg[1]_i_1 
       (.I0(w_digit_sel[0]),
        .I1(w_digit_sel[1]),
        .O(p_0_in[1]));
  FDCE #(
    .INIT(1'b0)) 
    \counter_reg_reg[0] 
       (.C(CLK),
        .CE(1'b1),
        .CLR(AR),
        .D(p_0_in[0]),
        .Q(w_digit_sel[0]));
  FDCE #(
    .INIT(1'b0)) 
    \counter_reg_reg[1] 
       (.C(CLK),
        .CE(1'b1),
        .CLR(AR),
        .D(p_0_in[1]),
        .Q(w_digit_sel[1]));
  (* SOFT_HLUTNM = "soft_lutpair6" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \fnd_com_OBUF[0]_inst_i_1 
       (.I0(w_digit_sel[0]),
        .I1(w_digit_sel[1]),
        .O(fnd_com_OBUF[0]));
  (* SOFT_HLUTNM = "soft_lutpair4" *) 
  LUT2 #(
    .INIT(4'hB)) 
    \fnd_com_OBUF[1]_inst_i_1 
       (.I0(w_digit_sel[1]),
        .I1(w_digit_sel[0]),
        .O(fnd_com_OBUF[1]));
  (* SOFT_HLUTNM = "soft_lutpair5" *) 
  LUT2 #(
    .INIT(4'hB)) 
    \fnd_com_OBUF[2]_inst_i_1 
       (.I0(w_digit_sel[0]),
        .I1(w_digit_sel[1]),
        .O(fnd_com_OBUF[2]));
  (* SOFT_HLUTNM = "soft_lutpair5" *) 
  LUT2 #(
    .INIT(4'h7)) 
    \fnd_com_OBUF[3]_inst_i_1 
       (.I0(w_digit_sel[0]),
        .I1(w_digit_sel[1]),
        .O(fnd_com_OBUF[3]));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT4 #(
    .INIT(16'h4184)) 
    \fnd_data_OBUF[0]_inst_i_1 
       (.I0(w_bcd[1]),
        .I1(w_bcd[0]),
        .I2(w_bcd[3]),
        .I3(w_bcd[2]),
        .O(fnd_data_OBUF[0]));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT4 #(
    .INIT(16'hAC48)) 
    \fnd_data_OBUF[1]_inst_i_1 
       (.I0(w_bcd[1]),
        .I1(w_bcd[2]),
        .I2(w_bcd[0]),
        .I3(w_bcd[3]),
        .O(fnd_data_OBUF[1]));
  (* SOFT_HLUTNM = "soft_lutpair2" *) 
  LUT4 #(
    .INIT(16'h80C2)) 
    \fnd_data_OBUF[2]_inst_i_1 
       (.I0(w_bcd[1]),
        .I1(w_bcd[2]),
        .I2(w_bcd[3]),
        .I3(w_bcd[0]),
        .O(fnd_data_OBUF[2]));
  (* SOFT_HLUTNM = "soft_lutpair1" *) 
  LUT4 #(
    .INIT(16'hC124)) 
    \fnd_data_OBUF[3]_inst_i_1 
       (.I0(w_bcd[3]),
        .I1(w_bcd[2]),
        .I2(w_bcd[1]),
        .I3(w_bcd[0]),
        .O(fnd_data_OBUF[3]));
  (* SOFT_HLUTNM = "soft_lutpair1" *) 
  LUT4 #(
    .INIT(16'h02BA)) 
    \fnd_data_OBUF[4]_inst_i_1 
       (.I0(w_bcd[0]),
        .I1(w_bcd[1]),
        .I2(w_bcd[2]),
        .I3(w_bcd[3]),
        .O(fnd_data_OBUF[4]));
  (* SOFT_HLUTNM = "soft_lutpair2" *) 
  LUT4 #(
    .INIT(16'h480E)) 
    \fnd_data_OBUF[5]_inst_i_1 
       (.I0(w_bcd[1]),
        .I1(w_bcd[0]),
        .I2(w_bcd[3]),
        .I3(w_bcd[2]),
        .O(fnd_data_OBUF[5]));
  LUT4 #(
    .INIT(16'h4019)) 
    \fnd_data_OBUF[6]_inst_i_1 
       (.I0(w_bcd[3]),
        .I1(w_bcd[2]),
        .I2(w_bcd[0]),
        .I3(w_bcd[1]),
        .O(fnd_data_OBUF[6]));
  LUT6 #(
    .INIT(64'h000000002C340000)) 
    \fnd_data_OBUF[6]_inst_i_11 
       (.I0(\fnd_data_OBUF[6]_inst_i_3_0 ),
        .I1(\fnd_data_OBUF[6]_inst_i_3_1 ),
        .I2(\fnd_data_OBUF[6]_inst_i_3_2 ),
        .I3(\fnd_data_OBUF[0]_inst_i_1_1 ),
        .I4(w_digit_sel[0]),
        .I5(w_digit_sel[1]),
        .O(\fnd_data_OBUF[6]_inst_i_11_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair4" *) 
  LUT4 #(
    .INIT(16'h0006)) 
    \fnd_data_OBUF[6]_inst_i_13 
       (.I0(a_IBUF),
        .I1(b_IBUF),
        .I2(w_digit_sel[1]),
        .I3(w_digit_sel[0]),
        .O(\fnd_data_OBUF[6]_inst_i_13_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair3" *) 
  LUT4 #(
    .INIT(16'h0040)) 
    \fnd_data_OBUF[6]_inst_i_14 
       (.I0(w_digit_sel[1]),
        .I1(w_digit_sel[0]),
        .I2(\fnd_data_OBUF[0]_inst_i_1_1 ),
        .I3(\fnd_data_OBUF[6]_inst_i_5_0 ),
        .O(\fnd_data_OBUF[6]_inst_i_14_n_0 ));
  LUT6 #(
    .INIT(64'h002200000022F000)) 
    \fnd_data_OBUF[6]_inst_i_15 
       (.I0(\fnd_data_OBUF[6]_inst_i_5_0 ),
        .I1(\fnd_data_OBUF[0]_inst_i_1_1 ),
        .I2(\fnd_data_OBUF[6]_inst_i_5_1 ),
        .I3(w_digit_sel[1]),
        .I4(w_digit_sel[0]),
        .I5(CO),
        .O(\fnd_data_OBUF[6]_inst_i_15_n_0 ));
  LUT6 #(
    .INIT(64'hBABABABAABBAABAB)) 
    \fnd_data_OBUF[6]_inst_i_2 
       (.I0(\fnd_data_OBUF[6]_inst_i_6_n_0 ),
        .I1(fnd_com_OBUF[0]),
        .I2(\fnd_data_OBUF[0]_inst_i_1_3 ),
        .I3(s__0),
        .I4(\fnd_data_OBUF[0]_inst_i_1_4 ),
        .I5(\fnd_data_OBUF[0]_inst_i_1_2 ),
        .O(w_bcd[3]));
  LUT6 #(
    .INIT(64'hABBABAABABBAABBA)) 
    \fnd_data_OBUF[6]_inst_i_3 
       (.I0(\fnd_data_OBUF[6]_inst_i_11_n_0 ),
        .I1(fnd_com_OBUF[0]),
        .I2(\fnd_data_OBUF[0]_inst_i_1_0 ),
        .I3(\fnd_data_OBUF[0]_inst_i_1_1 ),
        .I4(s__0),
        .I5(\fnd_data_OBUF[0]_inst_i_1_2 ),
        .O(w_bcd[2]));
  LUT6 #(
    .INIT(64'hAFEAAAEAAAEAAFEA)) 
    \fnd_data_OBUF[6]_inst_i_4 
       (.I0(\fnd_data_OBUF[6]_inst_i_13_n_0 ),
        .I1(\fnd_data_OBUF[0]_inst_i_1_2 ),
        .I2(w_digit_sel[0]),
        .I3(w_digit_sel[1]),
        .I4(CO),
        .I5(\fnd_data_OBUF[6]_inst_i_5_1 ),
        .O(w_bcd[0]));
  LUT6 #(
    .INIT(64'hFFFFFFFFAAAAAABE)) 
    \fnd_data_OBUF[6]_inst_i_5 
       (.I0(\fnd_data_OBUF[6]_inst_i_14_n_0 ),
        .I1(\fnd_data_OBUF[0]_inst_i_1_2 ),
        .I2(s__0),
        .I3(w_digit_sel[1]),
        .I4(w_digit_sel[0]),
        .I5(\fnd_data_OBUF[6]_inst_i_15_n_0 ),
        .O(w_bcd[1]));
  LUT6 #(
    .INIT(64'h0000000041080000)) 
    \fnd_data_OBUF[6]_inst_i_6 
       (.I0(\fnd_data_OBUF[0]_inst_i_1_1 ),
        .I1(\fnd_data_OBUF[6]_inst_i_3_2 ),
        .I2(\fnd_data_OBUF[6]_inst_i_3_1 ),
        .I3(\fnd_data_OBUF[6]_inst_i_3_0 ),
        .I4(w_digit_sel[0]),
        .I5(w_digit_sel[1]),
        .O(\fnd_data_OBUF[6]_inst_i_6_n_0 ));
endmodule

module digit_spliter
   (CO,
    \b[6] ,
    \a[2] ,
    s,
    \b[3] ,
    \a[4] ,
    b_IBUF,
    a_IBUF);
  output [0:0]CO;
  output \b[6] ;
  output \a[2] ;
  output [0:0]s;
  output \b[3] ;
  output [1:0]\a[4] ;
  input [7:0]b_IBUF;
  input [7:0]a_IBUF;

  wire [0:0]CO;
  wire \U_ADDER/a1/c3 ;
  wire \U_ADDER/a2/c2 ;
  wire \a[2] ;
  wire [1:0]\a[4] ;
  wire [7:0]a_IBUF;
  wire \b[3] ;
  wire \b[6] ;
  wire [7:0]b_IBUF;
  wire digit_1000__1_carry__0_i_1_n_0;
  wire digit_1000__1_carry__0_i_2_n_0;
  wire digit_1000__1_carry__0_i_3_n_0;
  wire digit_1000__1_carry__0_i_4_n_0;
  wire digit_1000__1_carry__0_n_3;
  wire digit_1000__1_carry_i_11_n_0;
  wire digit_1000__1_carry_i_1_n_0;
  wire digit_1000__1_carry_i_2_n_0;
  wire digit_1000__1_carry_i_3_n_0;
  wire digit_1000__1_carry_i_4_n_0;
  wire digit_1000__1_carry_i_5_n_0;
  wire digit_1000__1_carry_n_0;
  wire digit_1000__1_carry_n_1;
  wire digit_1000__1_carry_n_2;
  wire digit_1000__1_carry_n_3;
  wire [0:0]s;
  wire [3:0]NLW_digit_1000__1_carry_O_UNCONNECTED;
  wire [3:2]NLW_digit_1000__1_carry__0_CO_UNCONNECTED;
  wire [3:0]NLW_digit_1000__1_carry__0_O_UNCONNECTED;

  (* ADDER_THRESHOLD = "35" *) 
  CARRY4 digit_1000__1_carry
       (.CI(1'b0),
        .CO({digit_1000__1_carry_n_0,digit_1000__1_carry_n_1,digit_1000__1_carry_n_2,digit_1000__1_carry_n_3}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,digit_1000__1_carry_i_1_n_0,1'b0}),
        .O(NLW_digit_1000__1_carry_O_UNCONNECTED[3:0]),
        .S({digit_1000__1_carry_i_2_n_0,digit_1000__1_carry_i_3_n_0,digit_1000__1_carry_i_4_n_0,digit_1000__1_carry_i_5_n_0}));
  (* ADDER_THRESHOLD = "35" *) 
  CARRY4 digit_1000__1_carry__0
       (.CI(digit_1000__1_carry_n_0),
        .CO({NLW_digit_1000__1_carry__0_CO_UNCONNECTED[3:2],CO,digit_1000__1_carry__0_n_3}),
        .CYINIT(1'b0),
        .DI({1'b0,1'b0,digit_1000__1_carry__0_i_1_n_0,digit_1000__1_carry__0_i_2_n_0}),
        .O(NLW_digit_1000__1_carry__0_O_UNCONNECTED[3:0]),
        .S({1'b0,1'b0,digit_1000__1_carry__0_i_3_n_0,digit_1000__1_carry__0_i_4_n_0}));
  LUT5 #(
    .INIT(32'h9FF6F66F)) 
    digit_1000__1_carry__0_i_1
       (.I0(b_IBUF[7]),
        .I1(a_IBUF[7]),
        .I2(\U_ADDER/a2/c2 ),
        .I3(b_IBUF[6]),
        .I4(a_IBUF[6]),
        .O(digit_1000__1_carry__0_i_1_n_0));
  LUT2 #(
    .INIT(4'hB)) 
    digit_1000__1_carry__0_i_2
       (.I0(\b[6] ),
        .I1(s),
        .O(digit_1000__1_carry__0_i_2_n_0));
  LUT5 #(
    .INIT(32'hFE9797FE)) 
    digit_1000__1_carry__0_i_3
       (.I0(\U_ADDER/a2/c2 ),
        .I1(a_IBUF[6]),
        .I2(b_IBUF[6]),
        .I3(b_IBUF[7]),
        .I4(a_IBUF[7]),
        .O(digit_1000__1_carry__0_i_3_n_0));
  LUT6 #(
    .INIT(64'hC396963C963C3C69)) 
    digit_1000__1_carry__0_i_4
       (.I0(\b[6] ),
        .I1(a_IBUF[6]),
        .I2(b_IBUF[6]),
        .I3(b_IBUF[5]),
        .I4(a_IBUF[5]),
        .I5(\b[3] ),
        .O(digit_1000__1_carry__0_i_4_n_0));
  (* SOFT_HLUTNM = "soft_lutpair8" *) 
  LUT3 #(
    .INIT(8'hE8)) 
    digit_1000__1_carry__0_i_5
       (.I0(\b[3] ),
        .I1(a_IBUF[5]),
        .I2(b_IBUF[5]),
        .O(\U_ADDER/a2/c2 ));
  (* SOFT_HLUTNM = "soft_lutpair7" *) 
  LUT5 #(
    .INIT(32'hFFE8E800)) 
    digit_1000__1_carry__0_i_6
       (.I0(b_IBUF[3]),
        .I1(a_IBUF[3]),
        .I2(\U_ADDER/a1/c3 ),
        .I3(a_IBUF[4]),
        .I4(b_IBUF[4]),
        .O(\b[3] ));
  LUT2 #(
    .INIT(4'hB)) 
    digit_1000__1_carry_i_1
       (.I0(\b[6] ),
        .I1(\a[2] ),
        .O(digit_1000__1_carry_i_1_n_0));
  LUT3 #(
    .INIT(8'h96)) 
    digit_1000__1_carry_i_10
       (.I0(a_IBUF[3]),
        .I1(b_IBUF[3]),
        .I2(\U_ADDER/a1/c3 ),
        .O(\a[4] [0]));
  LUT2 #(
    .INIT(4'h9)) 
    digit_1000__1_carry_i_11
       (.I0(b_IBUF[7]),
        .I1(a_IBUF[7]),
        .O(digit_1000__1_carry_i_11_n_0));
  LUT6 #(
    .INIT(64'hFFFFE888E8880000)) 
    digit_1000__1_carry_i_12
       (.I0(b_IBUF[1]),
        .I1(a_IBUF[1]),
        .I2(b_IBUF[0]),
        .I3(a_IBUF[0]),
        .I4(a_IBUF[2]),
        .I5(b_IBUF[2]),
        .O(\U_ADDER/a1/c3 ));
  LUT2 #(
    .INIT(4'h6)) 
    digit_1000__1_carry_i_2
       (.I0(s),
        .I1(\b[6] ),
        .O(digit_1000__1_carry_i_2_n_0));
  LUT1 #(
    .INIT(2'h1)) 
    digit_1000__1_carry_i_3
       (.I0(\a[4] [1]),
        .O(digit_1000__1_carry_i_3_n_0));
  LUT3 #(
    .INIT(8'hD2)) 
    digit_1000__1_carry_i_4
       (.I0(\a[2] ),
        .I1(\b[6] ),
        .I2(\a[4] [0]),
        .O(digit_1000__1_carry_i_4_n_0));
  LUT2 #(
    .INIT(4'h6)) 
    digit_1000__1_carry_i_5
       (.I0(\a[2] ),
        .I1(\b[6] ),
        .O(digit_1000__1_carry_i_5_n_0));
  LUT6 #(
    .INIT(64'hA9A9A995A9959595)) 
    digit_1000__1_carry_i_6
       (.I0(digit_1000__1_carry_i_11_n_0),
        .I1(b_IBUF[6]),
        .I2(a_IBUF[6]),
        .I3(\b[3] ),
        .I4(a_IBUF[5]),
        .I5(b_IBUF[5]),
        .O(\b[6] ));
  LUT6 #(
    .INIT(64'h9996966696669666)) 
    digit_1000__1_carry_i_7
       (.I0(a_IBUF[2]),
        .I1(b_IBUF[2]),
        .I2(b_IBUF[1]),
        .I3(a_IBUF[1]),
        .I4(b_IBUF[0]),
        .I5(a_IBUF[0]),
        .O(\a[2] ));
  (* SOFT_HLUTNM = "soft_lutpair8" *) 
  LUT3 #(
    .INIT(8'h96)) 
    digit_1000__1_carry_i_8
       (.I0(a_IBUF[5]),
        .I1(b_IBUF[5]),
        .I2(\b[3] ),
        .O(s));
  (* SOFT_HLUTNM = "soft_lutpair7" *) 
  LUT5 #(
    .INIT(32'h99969666)) 
    digit_1000__1_carry_i_9
       (.I0(a_IBUF[4]),
        .I1(b_IBUF[4]),
        .I2(b_IBUF[3]),
        .I3(a_IBUF[3]),
        .I4(\U_ADDER/a1/c3 ),
        .O(\a[4] [1]));
endmodule

module fnd_controller
   (s,
    fnd_data_OBUF,
    fnd_com_OBUF,
    c1,
    \a[4] ,
    b_IBUF,
    a_IBUF,
    \fnd_data_OBUF[0]_inst_i_1 ,
    s__0,
    \fnd_data_OBUF[0]_inst_i_1_0 ,
    \fnd_data_OBUF[6]_inst_i_3 ,
    \fnd_data_OBUF[6]_inst_i_3_0 ,
    \fnd_data_OBUF[6]_inst_i_3_1 ,
    \fnd_data_OBUF[6]_inst_i_5 ,
    \fnd_data_OBUF[0]_inst_i_1_1 ,
    \fnd_data_OBUF[0]_inst_i_1_2 ,
    CLK,
    AR);
  output [2:0]s;
  output [6:0]fnd_data_OBUF;
  output [3:0]fnd_com_OBUF;
  output c1;
  output [1:0]\a[4] ;
  input [7:0]b_IBUF;
  input [7:0]a_IBUF;
  input \fnd_data_OBUF[0]_inst_i_1 ;
  input [0:0]s__0;
  input \fnd_data_OBUF[0]_inst_i_1_0 ;
  input \fnd_data_OBUF[6]_inst_i_3 ;
  input \fnd_data_OBUF[6]_inst_i_3_0 ;
  input \fnd_data_OBUF[6]_inst_i_3_1 ;
  input \fnd_data_OBUF[6]_inst_i_5 ;
  input \fnd_data_OBUF[0]_inst_i_1_1 ;
  input \fnd_data_OBUF[0]_inst_i_1_2 ;
  input CLK;
  input [0:0]AR;

  wire [0:0]AR;
  wire CLK;
  wire U_DS_n_0;
  wire [1:0]\a[4] ;
  wire [7:0]a_IBUF;
  wire [7:0]b_IBUF;
  wire c1;
  wire [3:0]fnd_com_OBUF;
  wire [6:0]fnd_data_OBUF;
  wire \fnd_data_OBUF[0]_inst_i_1 ;
  wire \fnd_data_OBUF[0]_inst_i_1_0 ;
  wire \fnd_data_OBUF[0]_inst_i_1_1 ;
  wire \fnd_data_OBUF[0]_inst_i_1_2 ;
  wire \fnd_data_OBUF[6]_inst_i_3 ;
  wire \fnd_data_OBUF[6]_inst_i_3_0 ;
  wire \fnd_data_OBUF[6]_inst_i_3_1 ;
  wire \fnd_data_OBUF[6]_inst_i_5 ;
  wire [2:0]s;
  wire [0:0]s__0;

  counter_4 U_COUNTER_4
       (.AR(AR),
        .CLK(CLK),
        .CO(U_DS_n_0),
        .a_IBUF(a_IBUF[0]),
        .b_IBUF(b_IBUF[0]),
        .fnd_com_OBUF(fnd_com_OBUF),
        .fnd_data_OBUF(fnd_data_OBUF),
        .\fnd_data_OBUF[0]_inst_i_1_0 (s[0]),
        .\fnd_data_OBUF[0]_inst_i_1_1 (\fnd_data_OBUF[0]_inst_i_1 ),
        .\fnd_data_OBUF[0]_inst_i_1_2 (\fnd_data_OBUF[0]_inst_i_1_0 ),
        .\fnd_data_OBUF[0]_inst_i_1_3 (\fnd_data_OBUF[0]_inst_i_1_1 ),
        .\fnd_data_OBUF[0]_inst_i_1_4 (\fnd_data_OBUF[0]_inst_i_1_2 ),
        .\fnd_data_OBUF[6]_inst_i_3_0 (\fnd_data_OBUF[6]_inst_i_3 ),
        .\fnd_data_OBUF[6]_inst_i_3_1 (\fnd_data_OBUF[6]_inst_i_3_0 ),
        .\fnd_data_OBUF[6]_inst_i_3_2 (\fnd_data_OBUF[6]_inst_i_3_1 ),
        .\fnd_data_OBUF[6]_inst_i_5_0 (\fnd_data_OBUF[6]_inst_i_5 ),
        .\fnd_data_OBUF[6]_inst_i_5_1 (s[2]),
        .s__0(s__0));
  digit_spliter U_DS
       (.CO(U_DS_n_0),
        .\a[2] (s[0]),
        .\a[4] (\a[4] ),
        .a_IBUF(a_IBUF),
        .\b[3] (c1),
        .\b[6] (s[2]),
        .b_IBUF(b_IBUF),
        .s(s[1]));
endmodule
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;
    parameter GRES_WIDTH = 10000;
    parameter GRES_START = 10000;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    wire GRESTORE;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;
    reg GRESTORE_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;
    assign (strong1, weak0) GRESTORE = GRESTORE_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

    initial begin 
	GRESTORE_int = 1'b0;
	#(GRES_START);
	GRESTORE_int = 1'b1;
	#(GRES_WIDTH);
	GRESTORE_int = 1'b0;
    end

endmodule
`endif
