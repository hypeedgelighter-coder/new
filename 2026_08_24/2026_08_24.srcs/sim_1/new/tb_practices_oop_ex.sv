`timescale 1ns / 1ps


module tb_practices_oop_ex ();

    // parent
    class base_packet;
        int id;

        function new(int id);
            this.id = id;
            $display(" 1) base_packet::new runs (id=%d)", id);
        endfunction
    endclass

    // child
    class eth_packet extends base_packet;
        bit [47:0] mac_da;
        function new(int id, bit [47:0] da);
            super.new(id);  // parent class init
            mac_da = da;
            $display(" 2) eth_packet::new runs (da = %012d)", da);
        endfunction
    endclass

    eth_packet e;

    initial begin
        $display("[ex01] executing a single line : eth_packet e = new()");
        e = new(7, 48'haabbccddeeff);
        $display(" 3) finished object : id = %d, (set by parent), da = %d (set by child)",
                 e.id, e.mac_da);
        $display("=> The child inherits the parent's member (id) and uses it as is");
    end

endmodule
