module test_firesim_pcis_width_bridge_basic;
   logic clk = 1'b0;
   logic resetn = 1'b0;

   logic [15:0] s_axi_awid = 16'h0;
   logic [63:0] s_axi_awaddr = 64'h0;
   logic [7:0]  s_axi_awlen = 8'h0;
   logic [2:0]  s_axi_awsize = 3'h6;
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
   logic [2:0]   s_axi_arsize = 3'h6;
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
   logic        m_axi_awvalid;
   logic        m_axi_awready = 1'b0;
   logic [63:0] m_axi_wdata;
   logic [7:0]  m_axi_wstrb;
   logic        m_axi_wlast;
   logic        m_axi_wvalid;
   logic        m_axi_wready = 1'b0;
   logic [15:0] m_axi_bid = 16'h0;
   logic [1:0]  m_axi_bresp = 2'h0;
   logic        m_axi_bvalid = 1'b0;
   logic        m_axi_bready;
   logic [15:0] m_axi_arid;
   logic [63:0] m_axi_araddr;
   logic [7:0]  m_axi_arlen;
   logic [2:0]  m_axi_arsize;
   logic        m_axi_arvalid;
   logic        m_axi_arready = 1'b0;
   logic [15:0] m_axi_rid = 16'h0;
   logic [63:0] m_axi_rdata = 64'h0;
   logic [1:0]  m_axi_rresp = 2'h0;
   logic        m_axi_rlast = 1'b0;
   logic        m_axi_rvalid = 1'b0;
   logic        m_axi_rready;

   logic [31:0] debug_write_state;
   logic [31:0] debug_read_state;
   logic [31:0] debug_wide_aw_fire_count;
   logic [31:0] debug_wide_w_fire_count;
   logic [31:0] debug_wide_b_fire_count;
   logic [31:0] debug_narrow_aw_fire_count;
   logic [31:0] debug_narrow_w_fire_count;
   logic [31:0] debug_narrow_b_fire_count;
   logic [31:0] debug_write_full512_count;
   logic [31:0] debug_write_multilane_count;
   logic [31:0] debug_write_partial_strobe_count;
   logic [31:0] debug_write_zero_strobe_count;
   logic [31:0] debug_write_resp_error_count;
   logic [31:0] debug_wide_ar_fire_count;
   logic [31:0] debug_wide_r_fire_count;
   logic [31:0] debug_narrow_ar_fire_count;
   logic [31:0] debug_narrow_r_fire_count;
   logic [31:0] debug_read_full512_count;
   logic [31:0] debug_read_multilane_count;
   logic [31:0] debug_read_resp_error_count;
   logic [31:0] debug_read_sub64_count;
   logic [63:0] debug_last_wide_awaddr;
   logic [63:0] debug_last_wide_araddr;
   logic [63:0] debug_last_wide_wstrb;
   logic [63:0] debug_last_narrow_wdata;
   logic [63:0] debug_last_narrow_rdata;
   logic [7:0]  debug_last_write_lane_mask;
   logic [7:0]  debug_last_read_lane_mask;
   logic [2:0]  debug_last_write_lane;
   logic [2:0]  debug_last_read_lane;

   always #5 clk = ~clk;

   firesim_pcis_width_bridge_512_to_64 dut (
      .clk(clk),
      .resetn(resetn),
      .s_axi_awid(s_axi_awid),
      .s_axi_awaddr(s_axi_awaddr),
      .s_axi_awlen(s_axi_awlen),
      .s_axi_awsize(s_axi_awsize),
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
      .m_axi_arvalid(m_axi_arvalid),
      .m_axi_arready(m_axi_arready),
      .m_axi_rid(m_axi_rid),
      .m_axi_rdata(m_axi_rdata),
      .m_axi_rresp(m_axi_rresp),
      .m_axi_rlast(m_axi_rlast),
      .m_axi_rvalid(m_axi_rvalid),
      .m_axi_rready(m_axi_rready),
      .debug_write_state(debug_write_state),
      .debug_read_state(debug_read_state),
      .debug_wide_aw_fire_count(debug_wide_aw_fire_count),
      .debug_wide_w_fire_count(debug_wide_w_fire_count),
      .debug_wide_b_fire_count(debug_wide_b_fire_count),
      .debug_narrow_aw_fire_count(debug_narrow_aw_fire_count),
      .debug_narrow_w_fire_count(debug_narrow_w_fire_count),
      .debug_narrow_b_fire_count(debug_narrow_b_fire_count),
      .debug_write_full512_count(debug_write_full512_count),
      .debug_write_multilane_count(debug_write_multilane_count),
      .debug_write_partial_strobe_count(debug_write_partial_strobe_count),
      .debug_write_zero_strobe_count(debug_write_zero_strobe_count),
      .debug_write_resp_error_count(debug_write_resp_error_count),
      .debug_wide_ar_fire_count(debug_wide_ar_fire_count),
      .debug_wide_r_fire_count(debug_wide_r_fire_count),
      .debug_narrow_ar_fire_count(debug_narrow_ar_fire_count),
      .debug_narrow_r_fire_count(debug_narrow_r_fire_count),
      .debug_read_full512_count(debug_read_full512_count),
      .debug_read_multilane_count(debug_read_multilane_count),
      .debug_read_resp_error_count(debug_read_resp_error_count),
      .debug_read_sub64_count(debug_read_sub64_count),
      .debug_last_wide_awaddr(debug_last_wide_awaddr),
      .debug_last_wide_araddr(debug_last_wide_araddr),
      .debug_last_wide_wstrb(debug_last_wide_wstrb),
      .debug_last_narrow_wdata(debug_last_narrow_wdata),
      .debug_last_narrow_rdata(debug_last_narrow_rdata),
      .debug_last_write_lane_mask(debug_last_write_lane_mask),
      .debug_last_read_lane_mask(debug_last_read_lane_mask),
      .debug_last_write_lane(debug_last_write_lane),
      .debug_last_read_lane(debug_last_read_lane)
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

   task automatic wait_narrow_write(input [2:0] lane, input [63:0] data, input [7:0] strb);
      int cycles;
      begin
         cycles = 0;
         m_axi_awready = 1'b1;
         m_axi_wready = 1'b1;
         #1;
         while (!(m_axi_awvalid && m_axi_wvalid)) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if (cycles > 20) begin
               $error("timeout waiting for narrow write lane %0d", lane);
               $finish;
            end
         end
         expect_eq(m_axi_awaddr, 64'h1000 + {58'b0, lane, 3'b0}, "narrow write address");
         expect_eq(m_axi_awlen, 8'h0, "narrow write awlen");
         expect_eq(m_axi_awsize, 3'h3, "narrow write awsize");
         expect_eq(m_axi_wdata, data, "narrow write data");
         expect_eq(m_axi_wstrb, strb, "narrow write strobe");
         expect_eq(m_axi_wlast, 1'b1, "narrow write last");
         @(posedge clk);
         #1;
         m_axi_awready = 1'b0;
         m_axi_wready = 1'b0;
         m_axi_bid = 16'h41;
         m_axi_bresp = 2'h0;
         m_axi_bvalid = 1'b1;
         wait_cycle();
         m_axi_bvalid = 1'b0;
      end
   endtask

   task automatic drive_wide_write(input [63:0] addr, input [63:0] strobe, input [511:0] data);
      begin
         s_axi_awid = 16'h41;
         s_axi_awaddr = addr;
         s_axi_awlen = 8'h0;
         s_axi_awsize = 3'h6;
         s_axi_wdata = data;
         s_axi_wstrb = strobe;
         s_axi_wlast = 1'b1;
         s_axi_awvalid = 1'b1;
         s_axi_wvalid = 1'b1;
         #1;
         expect_eq(s_axi_awready, 1'b1, "wide awready before write handshake");
         expect_eq(s_axi_wready, 1'b1, "wide wready before write handshake");
         @(posedge clk);
         #1;
         s_axi_awvalid = 1'b0;
         s_axi_wvalid = 1'b0;
      end
   endtask

   task automatic check_write_data_waits_for_address;
      begin
         s_axi_wdata = {8{64'hfeed_face_0123_4567}};
         s_axi_wstrb = 64'h0000_0000_0000_00ff;
         s_axi_wlast = 1'b1;
         s_axi_wvalid = 1'b1;
         #1;
         expect_eq(s_axi_awready, 1'b1, "awready while only wvalid is asserted");
         expect_eq(s_axi_wready, 1'b0, "wready must wait for address");
         wait_cycle();
         expect_eq(debug_wide_w_fire_count, 32'd0, "wide w count before address");

         s_axi_awid = 16'h41;
         s_axi_awaddr = 64'h1000;
         s_axi_awlen = 8'h0;
         s_axi_awsize = 3'h6;
         s_axi_awvalid = 1'b1;
         #1;
         expect_eq(s_axi_awready, 1'b1, "awready when address arrives after data");
         expect_eq(s_axi_wready, 1'b1, "wready once address is present");
         wait_cycle();
         s_axi_awvalid = 1'b0;
         s_axi_wvalid = 1'b0;
      end
   endtask

   task automatic complete_wide_b;
      int cycles;
      begin
         cycles = 0;
         s_axi_bready = 1'b1;
         #1;
         while (!s_axi_bvalid) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if (cycles > 20) begin
               $error("timeout waiting for wide bvalid");
               $finish;
            end
         end
         expect_eq(s_axi_bid, 16'h41, "wide bid");
         expect_eq(s_axi_bresp, 2'h0, "wide bresp");
         wait_cycle();
         s_axi_bready = 1'b0;
      end
   endtask

   task automatic drive_wide_read(input [63:0] addr, input [15:0] id);
      begin
         s_axi_arid = id;
         s_axi_araddr = addr;
         s_axi_arlen = 8'h0;
         s_axi_arsize = 3'h6;
         s_axi_arvalid = 1'b1;
         #1;
         expect_eq(s_axi_arready, 1'b1, "wide arready before read handshake");
         @(posedge clk);
         #1;
         s_axi_arvalid = 1'b0;
      end
   endtask

   task automatic complete_narrow_read(input [2:0] lane, input [15:0] id, input [63:0] data);
      int cycles;
      begin
         cycles = 0;
         m_axi_arready = 1'b1;
         #1;
         while (!m_axi_arvalid) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if (cycles > 20) begin
               $error("timeout waiting for narrow read lane %0d", lane);
               $finish;
            end
         end
         expect_eq(m_axi_arid, id, "narrow read id");
         expect_eq(m_axi_araddr, 64'h2000 + {58'b0, lane, 3'b0}, "narrow read address");
         expect_eq(m_axi_arlen, 8'h0, "narrow read arlen");
         expect_eq(m_axi_arsize, 3'h3, "narrow read arsize");
         @(posedge clk);
         #1;
         m_axi_arready = 1'b0;
         m_axi_rid = id;
         m_axi_rdata = data;
         m_axi_rresp = 2'h0;
         m_axi_rlast = 1'b1;
         m_axi_rvalid = 1'b1;
         wait_cycle();
         m_axi_rvalid = 1'b0;
      end
   endtask

   task automatic complete_wide_r(input [2:0] lane, input [15:0] id, input [63:0] data);
      logic [511:0] expected;
      int cycles;
      begin
         expected = 512'h0;
         expected[(lane * 64) +: 64] = data;
         cycles = 0;
         s_axi_rready = 1'b1;
         #1;
         while (!s_axi_rvalid) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if (cycles > 20) begin
               $error("timeout waiting for wide rvalid");
               $finish;
            end
         end
         expect_eq(s_axi_rid, id, "wide rid");
         expect_eq(s_axi_rdata, expected, "wide rdata lane placement");
         expect_eq(s_axi_rresp, 2'h0, "wide rresp");
         expect_eq(s_axi_rlast, 1'b1, "wide rlast");
         wait_cycle();
         s_axi_rready = 1'b0;
      end
   endtask

   initial begin
      repeat (4) wait_cycle();
      resetn = 1'b1;
      wait_cycle();

      check_write_data_waits_for_address();
      wait_narrow_write(3'd0, 64'hfeed_face_0123_4567, 8'hff);
      complete_wide_b();

      drive_wide_write(64'h1010, 64'h0000_0000_00ff_0000,
                       {64'h8877665544332211, 64'h7766554433221100,
                        64'h66554433221100ff, 64'h554433221100ffee,
                        64'h4433221100ffeedd, 64'ha5a5a5a55a5a5a5a,
                        64'h221100ffeeddccbb, 64'h1100ffeeddccbbaa});
      wait_narrow_write(3'd2, 64'ha5a5a5a55a5a5a5a, 8'hff);
      complete_wide_b();

      drive_wide_write(64'h1000, 64'hffff_ffff_ffff_ffff,
                       {64'h0707070707070707, 64'h0606060606060606,
                        64'h0505050505050505, 64'h0404040404040404,
                        64'h0303030303030303, 64'h0202020202020202,
                        64'h0101010101010101, 64'h0000000000000000});
      wait_narrow_write(3'd7, 64'h0707070707070707, 8'hff);
      wait_narrow_write(3'd6, 64'h0606060606060606, 8'hff);
      wait_narrow_write(3'd5, 64'h0505050505050505, 8'hff);
      wait_narrow_write(3'd4, 64'h0404040404040404, 8'hff);
      wait_narrow_write(3'd3, 64'h0303030303030303, 8'hff);
      wait_narrow_write(3'd2, 64'h0202020202020202, 8'hff);
      wait_narrow_write(3'd1, 64'h0101010101010101, 8'hff);
      wait_narrow_write(3'd0, 64'h0000000000000000, 8'hff);
      complete_wide_b();

      drive_wide_read(64'h2018, 16'h55);
      complete_narrow_read(3'd3, 16'h55, 64'hdead_beef_cafe_1234);
      complete_wide_r(3'd3, 16'h55, 64'hdead_beef_cafe_1234);

      expect_eq(debug_wide_aw_fire_count, 32'd3, "debug wide aw count");
      expect_eq(debug_wide_w_fire_count, 32'd3, "debug wide w count");
      expect_eq(debug_wide_b_fire_count, 32'd3, "debug wide b count");
      expect_eq(debug_narrow_aw_fire_count, 32'd10, "debug narrow aw count");
      expect_eq(debug_narrow_w_fire_count, 32'd10, "debug narrow w count");
      expect_eq(debug_narrow_b_fire_count, 32'd10, "debug narrow b count");
      expect_eq(debug_wide_ar_fire_count, 32'd1, "debug wide ar count");
      expect_eq(debug_wide_r_fire_count, 32'd1, "debug wide r count");
      expect_eq(debug_narrow_ar_fire_count, 32'd1, "debug narrow ar count");
      expect_eq(debug_narrow_r_fire_count, 32'd1, "debug narrow r count");

      $display("PASS test_firesim_pcis_width_bridge_basic");
      $finish;
   end
endmodule
