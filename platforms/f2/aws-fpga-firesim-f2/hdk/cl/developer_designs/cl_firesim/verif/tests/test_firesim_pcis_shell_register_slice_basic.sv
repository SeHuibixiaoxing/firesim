module test_firesim_pcis_shell_register_slice_basic;
   logic clk = 1'b0;
   logic resetn = 1'b0;

   logic [15:0] s_axi_awid = 16'h0;
   logic [63:0] s_axi_awaddr = 64'h0;
   logic [7:0]  s_axi_awlen = 8'h0;
   logic [2:0]  s_axi_awsize = 3'h0;
   logic [1:0]  s_axi_awburst = 2'h1;
   logic [0:0]  s_axi_awlock = 1'h0;
   logic [3:0]  s_axi_awcache = 4'h0;
   logic [2:0]  s_axi_awprot = 3'h0;
   logic [3:0]  s_axi_awregion = 4'h0;
   logic [3:0]  s_axi_awqos = 4'h0;
   logic        s_axi_awvalid = 1'b0;
   logic        s_axi_awready;
   logic [511:0] s_axi_wdata = 512'h0;
   logic [63:0]  s_axi_wstrb = 64'h0;
   logic         s_axi_wlast = 1'b0;
   logic         s_axi_wvalid = 1'b0;
   logic         s_axi_wready;
   logic [15:0]  s_axi_bid;
   logic [1:0]   s_axi_bresp;
   logic         s_axi_bvalid;
   logic         s_axi_bready = 1'b0;
   logic [15:0]  s_axi_arid = 16'h0;
   logic [63:0]  s_axi_araddr = 64'h0;
   logic [7:0]   s_axi_arlen = 8'h0;
   logic [2:0]   s_axi_arsize = 3'h0;
   logic [1:0]   s_axi_arburst = 2'h1;
   logic [0:0]   s_axi_arlock = 1'h0;
   logic [3:0]   s_axi_arcache = 4'h0;
   logic [2:0]   s_axi_arprot = 3'h0;
   logic [3:0]   s_axi_arregion = 4'h0;
   logic [3:0]   s_axi_arqos = 4'h0;
   logic         s_axi_arvalid = 1'b0;
   logic         s_axi_arready;
   logic [15:0]  s_axi_rid;
   logic [511:0] s_axi_rdata;
   logic [1:0]   s_axi_rresp;
   logic         s_axi_rlast;
   logic         s_axi_rvalid;
   logic         s_axi_rready = 1'b0;

   logic [15:0] m_axi_awid;
   logic [63:0] m_axi_awaddr;
   logic [7:0]  m_axi_awlen;
   logic [2:0]  m_axi_awsize;
   logic [1:0]  m_axi_awburst;
   logic [0:0]  m_axi_awlock;
   logic [3:0]  m_axi_awcache;
   logic [2:0]  m_axi_awprot;
   logic [3:0]  m_axi_awregion;
   logic [3:0]  m_axi_awqos;
   logic        m_axi_awvalid;
   logic        m_axi_awready = 1'b0;
   logic [511:0] m_axi_wdata;
   logic [63:0]  m_axi_wstrb;
   logic         m_axi_wlast;
   logic         m_axi_wvalid;
   logic         m_axi_wready = 1'b0;
   logic [15:0]  m_axi_bid = 16'h0;
   logic [1:0]   m_axi_bresp = 2'h0;
   logic         m_axi_bvalid = 1'b0;
   logic         m_axi_bready;
   logic [15:0]  m_axi_arid;
   logic [63:0]  m_axi_araddr;
   logic [7:0]   m_axi_arlen;
   logic [2:0]   m_axi_arsize;
   logic [1:0]   m_axi_arburst;
   logic [0:0]   m_axi_arlock;
   logic [3:0]   m_axi_arcache;
   logic [2:0]   m_axi_arprot;
   logic [3:0]   m_axi_arregion;
   logic [3:0]   m_axi_arqos;
   logic         m_axi_arvalid;
   logic         m_axi_arready = 1'b0;
   logic [15:0]  m_axi_rid = 16'h0;
   logic [511:0] m_axi_rdata = 512'h0;
   logic [1:0]   m_axi_rresp = 2'h0;
   logic         m_axi_rlast = 1'b0;
   logic         m_axi_rvalid = 1'b0;
   logic         m_axi_rready;

   always #5 clk = ~clk;

   firesim_pcis_shell_register_slice dut (
      .clk(clk),
      .resetn(resetn),
      .s_axi_awid(s_axi_awid),
      .s_axi_awaddr(s_axi_awaddr),
      .s_axi_awlen(s_axi_awlen),
      .s_axi_awsize(s_axi_awsize),
      .s_axi_awburst(s_axi_awburst),
      .s_axi_awlock(s_axi_awlock),
      .s_axi_awcache(s_axi_awcache),
      .s_axi_awprot(s_axi_awprot),
      .s_axi_awregion(s_axi_awregion),
      .s_axi_awqos(s_axi_awqos),
      .s_axi_awvalid(s_axi_awvalid),
      .s_axi_awready(s_axi_awready),
      .s_axi_wdata(s_axi_wdata),
      .s_axi_wstrb(s_axi_wstrb),
      .s_axi_wlast(s_axi_wlast),
      .s_axi_wvalid(s_axi_wvalid),
      .s_axi_wready(s_axi_wready),
      .s_axi_bid(s_axi_bid),
      .s_axi_bresp(s_axi_bresp),
      .s_axi_bvalid(s_axi_bvalid),
      .s_axi_bready(s_axi_bready),
      .s_axi_arid(s_axi_arid),
      .s_axi_araddr(s_axi_araddr),
      .s_axi_arlen(s_axi_arlen),
      .s_axi_arsize(s_axi_arsize),
      .s_axi_arburst(s_axi_arburst),
      .s_axi_arlock(s_axi_arlock),
      .s_axi_arcache(s_axi_arcache),
      .s_axi_arprot(s_axi_arprot),
      .s_axi_arregion(s_axi_arregion),
      .s_axi_arqos(s_axi_arqos),
      .s_axi_arvalid(s_axi_arvalid),
      .s_axi_arready(s_axi_arready),
      .s_axi_rid(s_axi_rid),
      .s_axi_rdata(s_axi_rdata),
      .s_axi_rresp(s_axi_rresp),
      .s_axi_rlast(s_axi_rlast),
      .s_axi_rvalid(s_axi_rvalid),
      .s_axi_rready(s_axi_rready),
      .m_axi_awid(m_axi_awid),
      .m_axi_awaddr(m_axi_awaddr),
      .m_axi_awlen(m_axi_awlen),
      .m_axi_awsize(m_axi_awsize),
      .m_axi_awburst(m_axi_awburst),
      .m_axi_awlock(m_axi_awlock),
      .m_axi_awcache(m_axi_awcache),
      .m_axi_awprot(m_axi_awprot),
      .m_axi_awregion(m_axi_awregion),
      .m_axi_awqos(m_axi_awqos),
      .m_axi_awvalid(m_axi_awvalid),
      .m_axi_awready(m_axi_awready),
      .m_axi_wdata(m_axi_wdata),
      .m_axi_wstrb(m_axi_wstrb),
      .m_axi_wlast(m_axi_wlast),
      .m_axi_wvalid(m_axi_wvalid),
      .m_axi_wready(m_axi_wready),
      .m_axi_bid(m_axi_bid),
      .m_axi_bresp(m_axi_bresp),
      .m_axi_bvalid(m_axi_bvalid),
      .m_axi_bready(m_axi_bready),
      .m_axi_arid(m_axi_arid),
      .m_axi_araddr(m_axi_araddr),
      .m_axi_arlen(m_axi_arlen),
      .m_axi_arsize(m_axi_arsize),
      .m_axi_arburst(m_axi_arburst),
      .m_axi_arlock(m_axi_arlock),
      .m_axi_arcache(m_axi_arcache),
      .m_axi_arprot(m_axi_arprot),
      .m_axi_arregion(m_axi_arregion),
      .m_axi_arqos(m_axi_arqos),
      .m_axi_arvalid(m_axi_arvalid),
      .m_axi_arready(m_axi_arready),
      .m_axi_rid(m_axi_rid),
      .m_axi_rdata(m_axi_rdata),
      .m_axi_rresp(m_axi_rresp),
      .m_axi_rlast(m_axi_rlast),
      .m_axi_rvalid(m_axi_rvalid),
      .m_axi_rready(m_axi_rready)
   );

   task automatic expect_eq(input [511:0] got, input [511:0] exp, input string name);
      begin
         if (got !== exp) begin
            $error("%s got=0x%0h exp=0x%0h", name, got, exp);
            $finish;
         end
      end
   endtask

   task automatic wait_cycle;
      begin
         @(posedge clk);
         #1;
      end
   endtask

   task automatic wait_for_awvalid;
      int cycles;
      begin
         cycles = 0;
         #1;
         while (!m_axi_awvalid) begin
            wait_cycle();
            cycles = cycles + 1;
            if (cycles > 100) begin
               $error("timeout waiting for m_axi_awvalid");
               $finish;
            end
         end
      end
   endtask

   task automatic wait_for_bvalid;
      int cycles;
      begin
         cycles = 0;
         #1;
         while (!s_axi_bvalid) begin
            wait_cycle();
            cycles = cycles + 1;
            if (cycles > 100) begin
               $error("timeout waiting for s_axi_bvalid");
               $finish;
            end
         end
      end
   endtask

   task automatic wait_for_arvalid;
      int cycles;
      begin
         cycles = 0;
         #1;
         while (!m_axi_arvalid) begin
            wait_cycle();
            cycles = cycles + 1;
            if (cycles > 100) begin
               $error("timeout waiting for m_axi_arvalid");
               $finish;
            end
         end
      end
   endtask

   task automatic wait_for_rvalid;
      int cycles;
      begin
         cycles = 0;
         #1;
         while (!s_axi_rvalid) begin
            wait_cycle();
            cycles = cycles + 1;
            if (cycles > 100) begin
               $error("timeout waiting for s_axi_rvalid");
               $finish;
            end
         end
      end
   endtask

   initial begin
      repeat (4) wait_cycle();
      resetn = 1'b1;
      wait_cycle();

      s_axi_awid = 16'h1234;
      s_axi_awaddr = 64'h0000_0000_4000_0010;
      s_axi_awlen = 8'h3;
      s_axi_awsize = 3'h6;
      s_axi_awburst = 2'h1;
      s_axi_awlock = 1'h0;
      s_axi_awcache = 4'ha;
      s_axi_awprot = 3'h5;
      s_axi_awregion = 4'h2;
      s_axi_awqos = 4'h7;
      s_axi_wdata = {8{64'h0123_4567_89ab_cdef}};
      s_axi_wstrb = 64'hffff_0000_ffff_0000;
      s_axi_wlast = 1'b1;
      s_axi_awvalid = 1'b1;
      s_axi_wvalid = 1'b1;
      m_axi_awready = 1'b1;
      m_axi_wready = 1'b1;
      wait_for_awvalid();
      expect_eq(m_axi_awid, 16'h1234, "write awid");
      expect_eq(m_axi_awaddr, 64'h0000_0000_4000_0010, "write awaddr");
      expect_eq(m_axi_awlen, 8'h3, "write awlen");
      expect_eq(m_axi_awsize, 3'h6, "write awsize");
      expect_eq(m_axi_awburst, 2'h1, "write awburst");
      expect_eq(m_axi_awcache, 4'ha, "write awcache");
      expect_eq(m_axi_awprot, 3'h5, "write awprot");
      expect_eq(m_axi_awregion, 4'h2, "write awregion");
      expect_eq(m_axi_awqos, 4'h7, "write awqos");
      expect_eq(m_axi_wdata, {8{64'h0123_4567_89ab_cdef}}, "write wdata");
      expect_eq(m_axi_wstrb, 64'hffff_0000_ffff_0000, "write wstrb");
      expect_eq(m_axi_wlast, 1'b1, "write wlast");
      wait_cycle();
      s_axi_awvalid = 1'b0;
      s_axi_wvalid = 1'b0;
      m_axi_awready = 1'b0;
      m_axi_wready = 1'b0;

      m_axi_bid = 16'h1234;
      m_axi_bresp = 2'h2;
      m_axi_bvalid = 1'b1;
      s_axi_bready = 1'b1;
      wait_for_bvalid();
      expect_eq(s_axi_bid, 16'h1234, "write bid");
      expect_eq(s_axi_bresp, 2'h2, "write bresp");
      wait_cycle();
      m_axi_bvalid = 1'b0;
      s_axi_bready = 1'b0;

      s_axi_arid = 16'h5678;
      s_axi_araddr = 64'h0000_0000_5000_0020;
      s_axi_arlen = 8'h5;
      s_axi_arsize = 3'h6;
      s_axi_arburst = 2'h1;
      s_axi_arlock = 1'h0;
      s_axi_arcache = 4'hb;
      s_axi_arprot = 3'h6;
      s_axi_arregion = 4'h3;
      s_axi_arqos = 4'h8;
      s_axi_arvalid = 1'b1;
      m_axi_arready = 1'b1;
      wait_for_arvalid();
      expect_eq(m_axi_arid, 16'h5678, "read arid");
      expect_eq(m_axi_araddr, 64'h0000_0000_5000_0020, "read araddr");
      expect_eq(m_axi_arlen, 8'h5, "read arlen");
      expect_eq(m_axi_arsize, 3'h6, "read arsize");
      expect_eq(m_axi_arburst, 2'h1, "read arburst");
      expect_eq(m_axi_arcache, 4'hb, "read arcache");
      expect_eq(m_axi_arprot, 3'h6, "read arprot");
      expect_eq(m_axi_arregion, 4'h3, "read arregion");
      expect_eq(m_axi_arqos, 4'h8, "read arqos");
      wait_cycle();
      s_axi_arvalid = 1'b0;
      m_axi_arready = 1'b0;

      m_axi_rid = 16'h5678;
      m_axi_rdata = {8{64'hfeed_face_cafe_beef}};
      m_axi_rresp = 2'h1;
      m_axi_rlast = 1'b1;
      m_axi_rvalid = 1'b1;
      s_axi_rready = 1'b1;
      wait_for_rvalid();
      expect_eq(s_axi_rid, 16'h5678, "read rid");
      expect_eq(s_axi_rdata, {8{64'hfeed_face_cafe_beef}}, "read rdata");
      expect_eq(s_axi_rresp, 2'h1, "read rresp");
      expect_eq(s_axi_rlast, 1'b1, "read rlast");
      wait_cycle();

      $display("PASS test_firesim_pcis_shell_register_slice_basic");
      $finish;
   end
endmodule
