module ddr_stat_split_pipe_test_dut #(
   parameter STAGES = 8
) (
   input  logic        clk,
   input  logic        rst_n,
   input  logic [31:0] sh_wdata,
   input  logic [7:0]  sh_addr,
   input  logic        sh_wr,
   input  logic        sh_rd,
   input  logic [31:0] ddr_rdata,
   input  logic        ddr_ack,
   input  logic [7:0]  ddr_int,
   output logic [31:0] pipe_wdata,
   output logic [7:0]  pipe_addr,
   output logic        pipe_wr,
   output logic        pipe_rd,
   output logic [31:0] pipe_rdata,
   output logic        pipe_ack,
   output logic [7:0]  pipe_int
);

   lib_pipe #(.WIDTH(32), .STAGES(STAGES)) PIPE_DDR_STAT_WDATA0 (
      .clk(clk),
      .rst_n(1'b1),
      .in_bus(sh_wdata),
      .out_bus(pipe_wdata)
   );

   lib_pipe #(.WIDTH(8), .STAGES(STAGES)) PIPE_DDR_STAT_ADDR0 (
      .clk(clk),
      .rst_n(1'b1),
      .in_bus(sh_addr),
      .out_bus(pipe_addr)
   );

   lib_pipe #(.WIDTH(1), .STAGES(STAGES)) PIPE_DDR_STAT_WR0 (
      .clk(clk),
      .rst_n(rst_n),
      .in_bus(sh_wr),
      .out_bus(pipe_wr)
   );

   lib_pipe #(.WIDTH(1), .STAGES(STAGES)) PIPE_DDR_STAT_RD0 (
      .clk(clk),
      .rst_n(rst_n),
      .in_bus(sh_rd),
      .out_bus(pipe_rd)
   );

   lib_pipe #(.WIDTH(32), .STAGES(STAGES)) PIPE_DDR_STAT_ACK_RDATA0 (
      .clk(clk),
      .rst_n(1'b1),
      .in_bus(ddr_rdata),
      .out_bus(pipe_rdata)
   );

   lib_pipe #(.WIDTH(1), .STAGES(STAGES)) PIPE_DDR_STAT_ACK0 (
      .clk(clk),
      .rst_n(rst_n),
      .in_bus(ddr_ack),
      .out_bus(pipe_ack)
   );

   lib_pipe #(.WIDTH(8), .STAGES(STAGES)) PIPE_DDR_STAT_INT0 (
      .clk(clk),
      .rst_n(rst_n),
      .in_bus(ddr_int),
      .out_bus(pipe_int)
   );

endmodule

module test_lib_pipe_ddr_stat_split;
   localparam int STAGES = 8;

   logic clk = 1'b0;
   logic rst_n = 1'b0;
   logic [31:0] sh_wdata = 32'h0;
   logic [7:0]  sh_addr = 8'h0;
   logic        sh_wr = 1'b0;
   logic        sh_rd = 1'b0;
   logic [31:0] ddr_rdata = 32'h0;
   logic        ddr_ack = 1'b0;
   logic [7:0]  ddr_int = 8'h0;
   logic [31:0] pipe_wdata;
   logic [7:0]  pipe_addr;
   logic        pipe_wr;
   logic        pipe_rd;
   logic [31:0] pipe_rdata;
   logic        pipe_ack;
   logic [7:0]  pipe_int;

   always #5 clk = ~clk;

   ddr_stat_split_pipe_test_dut #(.STAGES(STAGES)) dut (
      .clk(clk),
      .rst_n(rst_n),
      .sh_wdata(sh_wdata),
      .sh_addr(sh_addr),
      .sh_wr(sh_wr),
      .sh_rd(sh_rd),
      .ddr_rdata(ddr_rdata),
      .ddr_ack(ddr_ack),
      .ddr_int(ddr_int),
      .pipe_wdata(pipe_wdata),
      .pipe_addr(pipe_addr),
      .pipe_wr(pipe_wr),
      .pipe_rd(pipe_rd),
      .pipe_rdata(pipe_rdata),
      .pipe_ack(pipe_ack),
      .pipe_int(pipe_int)
   );

   task automatic fail(input string msg);
      begin
         $error("%s", msg);
         $finish;
      end
   endtask

   task automatic expect_eq(input [127:0] got, input [127:0] exp, input string name);
      begin
         if (got !== exp) begin
            $error("%s got=0x%0h exp=0x%0h", name, got, exp);
            $finish;
         end
      end
   endtask

   task automatic wait_stages;
      int i;
      begin
         for (i = 0; i < STAGES; i = i + 1) begin
            @(posedge clk);
            #1;
         end
      end
   endtask

   initial begin
      repeat (2) begin
         @(posedge clk);
         #1;
      end

      expect_eq(pipe_wr, 1'b0, "pipe_wr reset value");
      expect_eq(pipe_rd, 1'b0, "pipe_rd reset value");
      expect_eq(pipe_ack, 1'b0, "pipe_ack reset value");
      expect_eq(pipe_int, 8'h0, "pipe_int reset value");

      @(negedge clk);
      rst_n = 1'b1;
      sh_wdata = 32'h11223344;
      sh_addr = 8'h5a;
      sh_wr = 1'b1;
      sh_rd = 1'b0;
      ddr_rdata = 32'haabbccdd;
      ddr_ack = 1'b1;
      ddr_int = 8'hc3;

      wait_stages();
      expect_eq(pipe_wdata, 32'h11223344, "write data latency");
      expect_eq(pipe_addr, 8'h5a, "address latency");
      expect_eq(pipe_wr, 1'b1, "write pulse latency");
      expect_eq(pipe_rd, 1'b0, "read pulse latency");
      expect_eq(pipe_rdata, 32'haabbccdd, "ack rdata latency");
      expect_eq(pipe_ack, 1'b1, "ack pulse latency");
      expect_eq(pipe_int, 8'hc3, "interrupt latency");

      @(negedge clk);
      sh_wr = 1'b0;
      ddr_ack = 1'b0;
      ddr_int = 8'h00;
      wait_stages();
      expect_eq(pipe_wr, 1'b0, "write pulse clears after latency");
      expect_eq(pipe_ack, 1'b0, "ack pulse clears after latency");
      expect_eq(pipe_int, 8'h0, "interrupt clears after latency");

      @(negedge clk);
      sh_wdata = 32'h55667788;
      sh_addr = 8'h19;
      sh_rd = 1'b1;
      ddr_rdata = 32'h01020304;
      ddr_ack = 1'b1;
      wait_stages();
      expect_eq(pipe_wdata, 32'h55667788, "second data latency");
      expect_eq(pipe_addr, 8'h19, "second addr latency");
      expect_eq(pipe_rd, 1'b1, "read pulse latency");
      expect_eq(pipe_rdata, 32'h01020304, "second rdata latency");
      expect_eq(pipe_ack, 1'b1, "second ack latency");

      @(negedge clk);
      rst_n = 1'b0;
      sh_wr = 1'b1;
      sh_rd = 1'b1;
      ddr_ack = 1'b1;
      ddr_int = 8'hff;
      #1;
      expect_eq(pipe_wr, 1'b0, "write control async reset");
      expect_eq(pipe_rd, 1'b0, "read control async reset");
      expect_eq(pipe_ack, 1'b0, "ack control async reset");
      expect_eq(pipe_int, 8'h0, "interrupt control async reset");

      @(negedge clk);
      rst_n = 1'b1;
      sh_wr = 1'b0;
      sh_rd = 1'b0;
      ddr_ack = 1'b0;
      ddr_int = 8'h0;
      sh_wdata = 32'hcafef00d;
      sh_addr = 8'h7e;
      ddr_rdata = 32'h0badcafe;
      wait_stages();
      expect_eq(pipe_wdata, 32'hcafef00d, "data-only pipe still advances after reset");
      expect_eq(pipe_addr, 8'h7e, "addr-only pipe still advances after reset");
      expect_eq(pipe_rdata, 32'h0badcafe, "rdata-only pipe still advances after reset");

      $display("PASS test_lib_pipe_ddr_stat_split");
      $finish;
   end
endmodule
