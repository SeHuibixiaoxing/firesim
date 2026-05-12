// Amazon FPGA Hardware Development Kit
//
// Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
//
//    http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.

module firesim_pcis_width_bridge_512_to_64 (
   input  logic          clk,
   input  logic          resetn,

   input  logic [15:0]   s_axi_awid,
   input  logic [63:0]   s_axi_awaddr,
   input  logic [7:0]    s_axi_awlen,
   input  logic [2:0]    s_axi_awsize,
   input  logic          s_axi_awvalid,
   output logic          s_axi_awready,
   input  logic [511:0]  s_axi_wdata,
   input  logic [63:0]   s_axi_wstrb,
   input  logic          s_axi_wlast,
   input  logic          s_axi_wvalid,
   output logic          s_axi_wready,
   output logic [15:0]   s_axi_bid,
   output logic [1:0]    s_axi_bresp,
   output logic          s_axi_bvalid,
   input  logic          s_axi_bready,
   input  logic [15:0]   s_axi_arid,
   input  logic [63:0]   s_axi_araddr,
   input  logic [7:0]    s_axi_arlen,
   input  logic [2:0]    s_axi_arsize,
   input  logic          s_axi_arvalid,
   output logic          s_axi_arready,
   output logic [15:0]   s_axi_rid,
   output logic [511:0]  s_axi_rdata,
   output logic [1:0]    s_axi_rresp,
   output logic          s_axi_rlast,
   output logic          s_axi_rvalid,
   input  logic          s_axi_rready,

   output logic [15:0]   m_axi_awid,
   output logic [63:0]   m_axi_awaddr,
   output logic [7:0]    m_axi_awlen,
   output logic [2:0]    m_axi_awsize,
   output logic          m_axi_awvalid,
   input  logic          m_axi_awready,
   output logic [63:0]   m_axi_wdata,
   output logic [7:0]    m_axi_wstrb,
   output logic          m_axi_wlast,
   output logic          m_axi_wvalid,
   input  logic          m_axi_wready,
   input  logic [15:0]   m_axi_bid,
   input  logic [1:0]    m_axi_bresp,
   input  logic          m_axi_bvalid,
   output logic          m_axi_bready,
   output logic [15:0]   m_axi_arid,
   output logic [63:0]   m_axi_araddr,
   output logic [7:0]    m_axi_arlen,
   output logic [2:0]    m_axi_arsize,
   output logic          m_axi_arvalid,
   input  logic          m_axi_arready,
   input  logic [15:0]   m_axi_rid,
   input  logic [63:0]   m_axi_rdata,
   input  logic [1:0]    m_axi_rresp,
   input  logic          m_axi_rlast,
   input  logic          m_axi_rvalid,
   output logic          m_axi_rready,

   output logic [31:0]   debug_write_state,
   output logic [31:0]   debug_read_state,
   output logic [31:0]   debug_wide_aw_fire_count,
   output logic [31:0]   debug_wide_w_fire_count,
   output logic [31:0]   debug_wide_b_fire_count,
   output logic [31:0]   debug_narrow_aw_fire_count,
   output logic [31:0]   debug_narrow_w_fire_count,
   output logic [31:0]   debug_narrow_b_fire_count,
   output logic [31:0]   debug_write_full512_count,
   output logic [31:0]   debug_write_multilane_count,
   output logic [31:0]   debug_write_partial_strobe_count,
   output logic [31:0]   debug_write_zero_strobe_count,
   output logic [31:0]   debug_write_resp_error_count,
   output logic [31:0]   debug_wide_ar_fire_count,
   output logic [31:0]   debug_wide_r_fire_count,
   output logic [31:0]   debug_narrow_ar_fire_count,
   output logic [31:0]   debug_narrow_r_fire_count,
   output logic [31:0]   debug_read_full512_count,
   output logic [31:0]   debug_read_multilane_count,
   output logic [31:0]   debug_read_resp_error_count,
   output logic [31:0]   debug_read_sub64_count,
   output logic [63:0]   debug_last_wide_awaddr,
   output logic [63:0]   debug_last_wide_araddr,
   output logic [63:0]   debug_last_wide_wstrb,
   output logic [63:0]   debug_last_narrow_wdata,
   output logic [63:0]   debug_last_narrow_rdata,
   output logic [7:0]    debug_last_write_lane_mask,
   output logic [7:0]    debug_last_read_lane_mask,
   output logic [2:0]    debug_last_write_lane,
   output logic [2:0]    debug_last_read_lane
);

   localparam [1:0] WR_COLLECT = 2'd0;
   localparam [1:0] WR_LANE    = 2'd1;
   localparam [1:0] WR_RESP    = 2'd2;

   localparam [1:0] RD_IDLE    = 2'd0;
   localparam [1:0] RD_LANE    = 2'd1;
   localparam [1:0] RD_RESP    = 2'd2;

   function automatic [7:0] lane_mask_from_wstrb(input logic [63:0] strobe);
      integer i;
      begin
         lane_mask_from_wstrb = 8'h00;
         for (i = 0; i < 8; i = i + 1) begin
            lane_mask_from_wstrb[i] = |strobe[(i * 8) +: 8];
         end
      end
   endfunction

   function automatic [3:0] popcount8(input logic [7:0] value);
      integer i;
      begin
         popcount8 = 4'd0;
         for (i = 0; i < 8; i = i + 1) begin
            popcount8 = popcount8 + value[i];
         end
      end
   endfunction

   function automatic [2:0] first_set8(input logic [7:0] value);
      integer i;
      begin
         first_set8 = 3'd0;
         for (i = 7; i >= 0; i = i - 1) begin
            if (value[i]) begin
               first_set8 = i[2:0];
            end
         end
      end
   endfunction

   function automatic [63:0] axi_beat_addr(
      input logic [63:0] base,
      input logic [7:0]  beat,
      input logic [2:0]  size
   );
      begin
         axi_beat_addr = base + (({56'b0, beat}) << size);
      end
   endfunction

   function automatic [7:0] read_lane_mask(
      input logic [63:0] addr,
      input logic [2:0]  size
   );
      logic [2:0] lane;
      begin
         lane = addr[5:3];
         // F2 PCIS reports AWSIZE=6 for BAR4 reads, even when the host
         // software issues fpga_pci_peek64(). CPUManagedStreamEngine reads
         // are destructive 64-bit stream beats, so every host read must
         // consume exactly one downstream lane selected by the byte address.
         read_lane_mask = 8'b0000_0001 << lane;
      end
   endfunction

   function automatic has_partial_lane_strobe(input logic [63:0] strobe);
      integer i;
      begin
         has_partial_lane_strobe = 1'b0;
         for (i = 0; i < 8; i = i + 1) begin
            if ((|strobe[(i * 8) +: 8]) && (strobe[(i * 8) +: 8] != 8'hff)) begin
               has_partial_lane_strobe = 1'b1;
            end
         end
      end
   endfunction

   logic [1:0]   wr_state;
   logic         wr_aw_active;
   logic [15:0]  wr_awid_reg;
   logic [63:0]  wr_awaddr_reg;
   logic [7:0]   wr_awlen_reg;
   logic [2:0]   wr_awsize_reg;
   logic [7:0]   wr_wide_beat_idx_reg;
   logic         wr_wbuf_valid;
   logic [511:0] wr_wdata_reg;
   logic [63:0]  wr_wstrb_reg;
   logic         wr_wlast_reg;
   logic [7:0]   wr_lane_mask_reg;
   logic [2:0]   wr_lane_idx_reg;
   logic         wr_lane_aw_done;
   logic         wr_lane_w_done;
   logic [1:0]   wr_bresp_accum_reg;

   logic [1:0]   rd_state;
   logic [15:0]  rd_arid_reg;
   logic [63:0]  rd_araddr_reg;
   logic [7:0]   rd_arlen_reg;
   logic [2:0]   rd_arsize_reg;
   logic [7:0]   rd_wide_beat_idx_reg;
   logic [511:0] rd_rdata_accum_reg;
   logic [1:0]   rd_rresp_accum_reg;
   logic [7:0]   rd_lane_mask_reg;
   logic [2:0]   rd_lane_idx_reg;
   logic         rd_lane_ar_done;

   logic [31:0]  wide_aw_fire_count_reg;
   logic [31:0]  wide_w_fire_count_reg;
   logic [31:0]  wide_b_fire_count_reg;
   logic [31:0]  narrow_aw_fire_count_reg;
   logic [31:0]  narrow_w_fire_count_reg;
   logic [31:0]  narrow_b_fire_count_reg;
   logic [31:0]  write_full512_count_reg;
   logic [31:0]  write_multilane_count_reg;
   logic [31:0]  write_partial_strobe_count_reg;
   logic [31:0]  write_zero_strobe_count_reg;
   logic [31:0]  write_resp_error_count_reg;
   logic [31:0]  wide_ar_fire_count_reg;
   logic [31:0]  wide_r_fire_count_reg;
   logic [31:0]  narrow_ar_fire_count_reg;
   logic [31:0]  narrow_r_fire_count_reg;
   logic [31:0]  read_full512_count_reg;
   logic [31:0]  read_multilane_count_reg;
   logic [31:0]  read_resp_error_count_reg;
   logic [31:0]  read_sub64_count_reg;
   logic [63:0]  last_wide_awaddr_reg;
   logic [63:0]  last_wide_araddr_reg;
   logic [63:0]  last_wide_wstrb_reg;
   logic [63:0]  last_narrow_wdata_reg;
   logic [63:0]  last_narrow_rdata_reg;
   logic [7:0]   last_write_lane_mask_reg;
   logic [7:0]   last_read_lane_mask_reg;
   logic [2:0]   last_write_lane_reg;
   logic [2:0]   last_read_lane_reg;

   wire wr_aw_fire = s_axi_awvalid && s_axi_awready;
   wire wr_w_fire  = s_axi_wvalid && s_axi_wready;
   wire wr_b_fire  = s_axi_bvalid && s_axi_bready;
   wire wr_have_aw_after_collect = wr_aw_active || wr_aw_fire;
   wire wr_have_w_after_collect  = wr_wbuf_valid || wr_w_fire;
   wire [63:0] wr_collect_wstrb  = wr_w_fire ? s_axi_wstrb : wr_wstrb_reg;
   wire [7:0] wr_collect_lane_mask = lane_mask_from_wstrb(wr_collect_wstrb);
   wire [7:0] wr_lane_clear_mask = 8'b0000_0001 << wr_lane_idx_reg;
   wire [7:0] wr_remaining_lane_mask = wr_lane_mask_reg & ~wr_lane_clear_mask;
   wire wr_narrow_aw_fire = m_axi_awvalid && m_axi_awready;
   wire wr_narrow_w_fire  = m_axi_wvalid && m_axi_wready;
   wire wr_narrow_b_fire  = m_axi_bvalid && m_axi_bready;
   wire wr_lane_complete  = (wr_state == WR_LANE) &&
                            wr_narrow_b_fire &&
                            (wr_lane_aw_done || wr_narrow_aw_fire) &&
                            (wr_lane_w_done || wr_narrow_w_fire);
   wire wr_last_wide_beat = wr_wlast_reg || (wr_wide_beat_idx_reg == wr_awlen_reg);
   wire [63:0] wr_current_beat_addr = axi_beat_addr(wr_awaddr_reg, wr_wide_beat_idx_reg, wr_awsize_reg);
   wire [63:0] wr_current_aligned_addr = {wr_current_beat_addr[63:6], 6'b0};
   wire [63:0] wr_current_lane_addr = wr_current_aligned_addr + {58'b0, wr_lane_idx_reg, 3'b0};

   wire rd_ar_fire = s_axi_arvalid && s_axi_arready;
   wire rd_r_fire  = s_axi_rvalid && s_axi_rready;
   wire rd_narrow_ar_fire = m_axi_arvalid && m_axi_arready;
   wire rd_narrow_r_fire  = m_axi_rvalid && m_axi_rready;
   wire rd_lane_complete  = (rd_state == RD_LANE) &&
                            rd_narrow_r_fire &&
                            (rd_lane_ar_done || rd_narrow_ar_fire);
   wire [7:0] rd_lane_clear_mask = 8'b0000_0001 << rd_lane_idx_reg;
   wire [7:0] rd_remaining_lane_mask = rd_lane_mask_reg & ~rd_lane_clear_mask;
   wire rd_last_wide_beat = rd_wide_beat_idx_reg == rd_arlen_reg;
   wire [63:0] rd_current_beat_addr = axi_beat_addr(rd_araddr_reg, rd_wide_beat_idx_reg, rd_arsize_reg);
   wire [63:0] rd_current_aligned_addr = {rd_current_beat_addr[63:6], 6'b0};
   wire [63:0] rd_current_lane_addr = rd_current_aligned_addr + {58'b0, rd_lane_idx_reg, 3'b0};
   wire [7:0] rd_first_lane_mask = read_lane_mask(s_axi_araddr, s_axi_arsize);
   wire [63:0] rd_next_beat_addr = axi_beat_addr(rd_araddr_reg, rd_wide_beat_idx_reg + 8'd1, rd_arsize_reg);
   wire [7:0] rd_next_lane_mask = read_lane_mask(rd_next_beat_addr, rd_arsize_reg);

   always_comb begin
      s_axi_awready = (wr_state == WR_COLLECT) && !wr_aw_active;
      s_axi_wready  = (wr_state == WR_COLLECT) && !wr_wbuf_valid &&
                      (wr_aw_active || wr_aw_fire);
      s_axi_bid     = wr_awid_reg;
      s_axi_bresp   = wr_bresp_accum_reg;
      s_axi_bvalid  = (wr_state == WR_RESP);

      m_axi_awid    = wr_awid_reg;
      m_axi_awaddr  = wr_current_lane_addr;
      m_axi_awlen   = 8'd0;
      m_axi_awsize  = 3'd3;
      m_axi_awvalid = (wr_state == WR_LANE) && !wr_lane_aw_done;
      m_axi_wdata   = wr_wdata_reg[(wr_lane_idx_reg * 64) +: 64];
      m_axi_wstrb   = wr_wstrb_reg[(wr_lane_idx_reg * 8) +: 8];
      m_axi_wlast   = 1'b1;
      m_axi_wvalid  = (wr_state == WR_LANE) && !wr_lane_w_done;
      m_axi_bready  = (wr_state == WR_LANE);

      s_axi_arready = (rd_state == RD_IDLE);
      s_axi_rid     = rd_arid_reg;
      s_axi_rdata   = rd_rdata_accum_reg;
      s_axi_rresp   = rd_rresp_accum_reg;
      s_axi_rlast   = rd_last_wide_beat;
      s_axi_rvalid  = (rd_state == RD_RESP);

      m_axi_arid    = rd_arid_reg;
      m_axi_araddr  = rd_current_lane_addr;
      m_axi_arlen   = 8'd0;
      m_axi_arsize  = 3'd3;
      m_axi_arvalid = (rd_state == RD_LANE) && !rd_lane_ar_done;
      m_axi_rready  = (rd_state == RD_LANE);
   end

   always_ff @(posedge clk or negedge resetn) begin
      if (!resetn) begin
         wr_state <= WR_COLLECT;
         wr_aw_active <= 1'b0;
         wr_awid_reg <= 16'd0;
         wr_awaddr_reg <= 64'd0;
         wr_awlen_reg <= 8'd0;
         wr_awsize_reg <= 3'd0;
         wr_wide_beat_idx_reg <= 8'd0;
         wr_wbuf_valid <= 1'b0;
         wr_wdata_reg <= 512'd0;
         wr_wstrb_reg <= 64'd0;
         wr_wlast_reg <= 1'b0;
         wr_lane_mask_reg <= 8'd0;
         wr_lane_idx_reg <= 3'd0;
         wr_lane_aw_done <= 1'b0;
         wr_lane_w_done <= 1'b0;
         wr_bresp_accum_reg <= 2'd0;

         rd_state <= RD_IDLE;
         rd_arid_reg <= 16'd0;
         rd_araddr_reg <= 64'd0;
         rd_arlen_reg <= 8'd0;
         rd_arsize_reg <= 3'd0;
         rd_wide_beat_idx_reg <= 8'd0;
         rd_rdata_accum_reg <= 512'd0;
         rd_rresp_accum_reg <= 2'd0;
         rd_lane_mask_reg <= 8'd0;
         rd_lane_idx_reg <= 3'd0;
         rd_lane_ar_done <= 1'b0;

         wide_aw_fire_count_reg <= 32'd0;
         wide_w_fire_count_reg <= 32'd0;
         wide_b_fire_count_reg <= 32'd0;
         narrow_aw_fire_count_reg <= 32'd0;
         narrow_w_fire_count_reg <= 32'd0;
         narrow_b_fire_count_reg <= 32'd0;
         write_full512_count_reg <= 32'd0;
         write_multilane_count_reg <= 32'd0;
         write_partial_strobe_count_reg <= 32'd0;
         write_zero_strobe_count_reg <= 32'd0;
         write_resp_error_count_reg <= 32'd0;
         wide_ar_fire_count_reg <= 32'd0;
         wide_r_fire_count_reg <= 32'd0;
         narrow_ar_fire_count_reg <= 32'd0;
         narrow_r_fire_count_reg <= 32'd0;
         read_full512_count_reg <= 32'd0;
         read_multilane_count_reg <= 32'd0;
         read_resp_error_count_reg <= 32'd0;
         read_sub64_count_reg <= 32'd0;
         last_wide_awaddr_reg <= 64'd0;
         last_wide_araddr_reg <= 64'd0;
         last_wide_wstrb_reg <= 64'd0;
         last_narrow_wdata_reg <= 64'd0;
         last_narrow_rdata_reg <= 64'd0;
         last_write_lane_mask_reg <= 8'd0;
         last_read_lane_mask_reg <= 8'd0;
         last_write_lane_reg <= 3'd0;
         last_read_lane_reg <= 3'd0;
      end else begin
         if (wr_aw_fire) begin
            wide_aw_fire_count_reg <= wide_aw_fire_count_reg + 1'b1;
            wr_aw_active <= 1'b1;
            wr_awid_reg <= s_axi_awid;
            wr_awaddr_reg <= s_axi_awaddr;
            wr_awlen_reg <= s_axi_awlen;
            wr_awsize_reg <= s_axi_awsize;
            wr_wide_beat_idx_reg <= 8'd0;
            wr_bresp_accum_reg <= 2'd0;
            last_wide_awaddr_reg <= s_axi_awaddr;
         end

         if (wr_w_fire) begin
            wide_w_fire_count_reg <= wide_w_fire_count_reg + 1'b1;
            wr_wbuf_valid <= 1'b1;
            wr_wdata_reg <= s_axi_wdata;
            wr_wstrb_reg <= s_axi_wstrb;
            wr_wlast_reg <= s_axi_wlast;
            last_wide_wstrb_reg <= s_axi_wstrb;
         end
         if (wr_b_fire) begin
            wide_b_fire_count_reg <= wide_b_fire_count_reg + 1'b1;
         end
         if (wr_narrow_aw_fire) begin
            narrow_aw_fire_count_reg <= narrow_aw_fire_count_reg + 1'b1;
         end
         if (wr_narrow_w_fire) begin
            narrow_w_fire_count_reg <= narrow_w_fire_count_reg + 1'b1;
            last_narrow_wdata_reg <= m_axi_wdata;
         end
         if (wr_narrow_b_fire) begin
            narrow_b_fire_count_reg <= narrow_b_fire_count_reg + 1'b1;
            if (m_axi_bresp != 2'd0) begin
               write_resp_error_count_reg <= write_resp_error_count_reg + 1'b1;
            end
         end

         case (wr_state)
           WR_COLLECT: begin
              if (wr_have_aw_after_collect && wr_have_w_after_collect) begin
                 wr_lane_mask_reg <= wr_collect_lane_mask;
                 wr_lane_idx_reg <= first_set8(wr_collect_lane_mask);
                 wr_lane_aw_done <= 1'b0;
                 wr_lane_w_done <= 1'b0;
                 last_write_lane_mask_reg <= wr_collect_lane_mask;
                 if (wr_collect_lane_mask == 8'hff) begin
                    write_full512_count_reg <= write_full512_count_reg + 1'b1;
                 end
                 if (popcount8(wr_collect_lane_mask) > 4'd1) begin
                    write_multilane_count_reg <= write_multilane_count_reg + 1'b1;
                 end
                 if (has_partial_lane_strobe(wr_collect_wstrb)) begin
                    write_partial_strobe_count_reg <= write_partial_strobe_count_reg + 1'b1;
                 end
                 if (wr_collect_lane_mask == 8'h00) begin
                    write_zero_strobe_count_reg <= write_zero_strobe_count_reg + 1'b1;
                    wr_wbuf_valid <= 1'b0;
                    if (wr_wlast_reg || (wr_wide_beat_idx_reg == wr_awlen_reg)) begin
                       wr_state <= WR_RESP;
                    end else begin
                       wr_wide_beat_idx_reg <= wr_wide_beat_idx_reg + 1'b1;
                    end
                 end else begin
                    wr_state <= WR_LANE;
                 end
              end
           end
           WR_LANE: begin
              if (wr_narrow_aw_fire) begin
                 wr_lane_aw_done <= 1'b1;
              end
              if (wr_narrow_w_fire) begin
                 wr_lane_w_done <= 1'b1;
              end
              if (wr_narrow_b_fire) begin
                 wr_bresp_accum_reg <= wr_bresp_accum_reg | m_axi_bresp;
              end
              if (wr_lane_complete) begin
                 last_write_lane_reg <= wr_lane_idx_reg;
                 wr_lane_aw_done <= 1'b0;
                 wr_lane_w_done <= 1'b0;
                 if (wr_remaining_lane_mask != 8'h00) begin
                    wr_lane_mask_reg <= wr_remaining_lane_mask;
                    wr_lane_idx_reg <= first_set8(wr_remaining_lane_mask);
                 end else begin
                    wr_lane_mask_reg <= 8'h00;
                    wr_wbuf_valid <= 1'b0;
                    if (wr_last_wide_beat) begin
                       wr_state <= WR_RESP;
                    end else begin
                       wr_wide_beat_idx_reg <= wr_wide_beat_idx_reg + 1'b1;
                       wr_state <= WR_COLLECT;
                    end
                 end
              end
           end
           WR_RESP: begin
              if (wr_b_fire) begin
                 wr_aw_active <= 1'b0;
                 wr_state <= WR_COLLECT;
              end
           end
           default: begin
              wr_state <= WR_COLLECT;
           end
         endcase

         if (rd_ar_fire) begin
            wide_ar_fire_count_reg <= wide_ar_fire_count_reg + 1'b1;
            rd_arid_reg <= s_axi_arid;
            rd_araddr_reg <= s_axi_araddr;
            rd_arlen_reg <= s_axi_arlen;
            rd_arsize_reg <= s_axi_arsize;
            rd_wide_beat_idx_reg <= 8'd0;
            rd_rdata_accum_reg <= 512'd0;
            rd_rresp_accum_reg <= 2'd0;
            rd_lane_mask_reg <= rd_first_lane_mask;
            rd_lane_idx_reg <= first_set8(rd_first_lane_mask);
            rd_lane_ar_done <= 1'b0;
            rd_state <= RD_LANE;
            last_wide_araddr_reg <= s_axi_araddr;
            last_read_lane_mask_reg <= rd_first_lane_mask;
            if (rd_first_lane_mask == 8'hff) begin
               read_full512_count_reg <= read_full512_count_reg + 1'b1;
            end
            if (popcount8(rd_first_lane_mask) > 4'd1) begin
               read_multilane_count_reg <= read_multilane_count_reg + 1'b1;
            end
            if (s_axi_arsize < 3'd3) begin
               read_sub64_count_reg <= read_sub64_count_reg + 1'b1;
            end
         end

         if (rd_r_fire) begin
            wide_r_fire_count_reg <= wide_r_fire_count_reg + 1'b1;
         end
         if (rd_narrow_ar_fire) begin
            narrow_ar_fire_count_reg <= narrow_ar_fire_count_reg + 1'b1;
         end
         if (rd_narrow_r_fire) begin
            narrow_r_fire_count_reg <= narrow_r_fire_count_reg + 1'b1;
            last_narrow_rdata_reg <= m_axi_rdata;
            if (m_axi_rresp != 2'd0) begin
               read_resp_error_count_reg <= read_resp_error_count_reg + 1'b1;
            end
         end

         case (rd_state)
           RD_IDLE: begin
           end
           RD_LANE: begin
              if (rd_narrow_ar_fire) begin
                 rd_lane_ar_done <= 1'b1;
              end
              if (rd_narrow_r_fire) begin
                 rd_rdata_accum_reg[(rd_lane_idx_reg * 64) +: 64] <= m_axi_rdata;
                 rd_rresp_accum_reg <= rd_rresp_accum_reg | m_axi_rresp;
              end
              if (rd_lane_complete) begin
                 last_read_lane_reg <= rd_lane_idx_reg;
                 rd_lane_ar_done <= 1'b0;
                 if (rd_remaining_lane_mask != 8'h00) begin
                    rd_lane_mask_reg <= rd_remaining_lane_mask;
                    rd_lane_idx_reg <= first_set8(rd_remaining_lane_mask);
                 end else begin
                    rd_lane_mask_reg <= 8'h00;
                    rd_state <= RD_RESP;
                 end
              end
           end
           RD_RESP: begin
              if (rd_r_fire) begin
                 if (rd_last_wide_beat) begin
                    rd_state <= RD_IDLE;
                 end else begin
                    rd_wide_beat_idx_reg <= rd_wide_beat_idx_reg + 1'b1;
                    rd_rdata_accum_reg <= 512'd0;
                    rd_rresp_accum_reg <= 2'd0;
                    rd_lane_mask_reg <= rd_next_lane_mask;
                    rd_lane_idx_reg <= first_set8(rd_next_lane_mask);
                    rd_lane_ar_done <= 1'b0;
                    rd_state <= RD_LANE;
                    last_read_lane_mask_reg <= rd_next_lane_mask;
                    if (rd_next_lane_mask == 8'hff) begin
                       read_full512_count_reg <= read_full512_count_reg + 1'b1;
                    end
                    if (popcount8(rd_next_lane_mask) > 4'd1) begin
                       read_multilane_count_reg <= read_multilane_count_reg + 1'b1;
                    end
                 end
              end
           end
           default: begin
              rd_state <= RD_IDLE;
           end
         endcase
      end
   end

   assign debug_write_state = {30'd0, wr_state};
   assign debug_read_state = {30'd0, rd_state};
   assign debug_wide_aw_fire_count = wide_aw_fire_count_reg;
   assign debug_wide_w_fire_count = wide_w_fire_count_reg;
   assign debug_wide_b_fire_count = wide_b_fire_count_reg;
   assign debug_narrow_aw_fire_count = narrow_aw_fire_count_reg;
   assign debug_narrow_w_fire_count = narrow_w_fire_count_reg;
   assign debug_narrow_b_fire_count = narrow_b_fire_count_reg;
   assign debug_write_full512_count = write_full512_count_reg;
   assign debug_write_multilane_count = write_multilane_count_reg;
   assign debug_write_partial_strobe_count = write_partial_strobe_count_reg;
   assign debug_write_zero_strobe_count = write_zero_strobe_count_reg;
   assign debug_write_resp_error_count = write_resp_error_count_reg;
   assign debug_wide_ar_fire_count = wide_ar_fire_count_reg;
   assign debug_wide_r_fire_count = wide_r_fire_count_reg;
   assign debug_narrow_ar_fire_count = narrow_ar_fire_count_reg;
   assign debug_narrow_r_fire_count = narrow_r_fire_count_reg;
   assign debug_read_full512_count = read_full512_count_reg;
   assign debug_read_multilane_count = read_multilane_count_reg;
   assign debug_read_resp_error_count = read_resp_error_count_reg;
   assign debug_read_sub64_count = read_sub64_count_reg;
   assign debug_last_wide_awaddr = last_wide_awaddr_reg;
   assign debug_last_wide_araddr = last_wide_araddr_reg;
   assign debug_last_wide_wstrb = last_wide_wstrb_reg;
   assign debug_last_narrow_wdata = last_narrow_wdata_reg;
   assign debug_last_narrow_rdata = last_narrow_rdata_reg;
   assign debug_last_write_lane_mask = last_write_lane_mask_reg;
   assign debug_last_read_lane_mask = last_read_lane_mask_reg;
   assign debug_last_write_lane = last_write_lane_reg;
   assign debug_last_read_lane = last_read_lane_reg;

endmodule

module firesim_pcis_shell_register_slice (
   input  logic          clk,
   input  logic          resetn,

   input  logic [15:0]   s_axi_awid,
   input  logic [63:0]   s_axi_awaddr,
   input  logic [7:0]    s_axi_awlen,
   input  logic [2:0]    s_axi_awsize,
   input  logic [1:0]    s_axi_awburst,
   input  logic [0:0]    s_axi_awlock,
   input  logic [3:0]    s_axi_awcache,
   input  logic [2:0]    s_axi_awprot,
   input  logic [3:0]    s_axi_awregion,
   input  logic [3:0]    s_axi_awqos,
   input  logic          s_axi_awvalid,
   output logic          s_axi_awready,
   input  logic [511:0]  s_axi_wdata,
   input  logic [63:0]   s_axi_wstrb,
   input  logic          s_axi_wlast,
   input  logic          s_axi_wvalid,
   output logic          s_axi_wready,
   output logic [15:0]   s_axi_bid,
   output logic [1:0]    s_axi_bresp,
   output logic          s_axi_bvalid,
   input  logic          s_axi_bready,
   input  logic [15:0]   s_axi_arid,
   input  logic [63:0]   s_axi_araddr,
   input  logic [7:0]    s_axi_arlen,
   input  logic [2:0]    s_axi_arsize,
   input  logic [1:0]    s_axi_arburst,
   input  logic [0:0]    s_axi_arlock,
   input  logic [3:0]    s_axi_arcache,
   input  logic [2:0]    s_axi_arprot,
   input  logic [3:0]    s_axi_arregion,
   input  logic [3:0]    s_axi_arqos,
   input  logic          s_axi_arvalid,
   output logic          s_axi_arready,
   output logic [15:0]   s_axi_rid,
   output logic [511:0]  s_axi_rdata,
   output logic [1:0]    s_axi_rresp,
   output logic          s_axi_rlast,
   output logic          s_axi_rvalid,
   input  logic          s_axi_rready,

   output logic [15:0]   m_axi_awid,
   output logic [63:0]   m_axi_awaddr,
   output logic [7:0]    m_axi_awlen,
   output logic [2:0]    m_axi_awsize,
   output logic [1:0]    m_axi_awburst,
   output logic [0:0]    m_axi_awlock,
   output logic [3:0]    m_axi_awcache,
   output logic [2:0]    m_axi_awprot,
   output logic [3:0]    m_axi_awregion,
   output logic [3:0]    m_axi_awqos,
   output logic          m_axi_awvalid,
   input  logic          m_axi_awready,
   output logic [511:0]  m_axi_wdata,
   output logic [63:0]   m_axi_wstrb,
   output logic          m_axi_wlast,
   output logic          m_axi_wvalid,
   input  logic          m_axi_wready,
   input  logic [15:0]   m_axi_bid,
   input  logic [1:0]    m_axi_bresp,
   input  logic          m_axi_bvalid,
   output logic          m_axi_bready,
   output logic [15:0]   m_axi_arid,
   output logic [63:0]   m_axi_araddr,
   output logic [7:0]    m_axi_arlen,
   output logic [2:0]    m_axi_arsize,
   output logic [1:0]    m_axi_arburst,
   output logic [0:0]    m_axi_arlock,
   output logic [3:0]    m_axi_arcache,
   output logic [2:0]    m_axi_arprot,
   output logic [3:0]    m_axi_arregion,
   output logic [3:0]    m_axi_arqos,
   output logic          m_axi_arvalid,
   input  logic          m_axi_arready,
   input  logic [15:0]   m_axi_rid,
   input  logic [511:0]  m_axi_rdata,
   input  logic [1:0]    m_axi_rresp,
   input  logic          m_axi_rlast,
   input  logic          m_axi_rvalid,
   output logic          m_axi_rready
);

   logic [15:0]  pcis_slr2_awid;
   logic [63:0]  pcis_slr2_awaddr;
   logic [7:0]   pcis_slr2_awlen;
   logic [2:0]   pcis_slr2_awsize;
   logic [1:0]   pcis_slr2_awburst;
   logic [0:0]   pcis_slr2_awlock;
   logic [3:0]   pcis_slr2_awcache;
   logic [2:0]   pcis_slr2_awprot;
   logic [3:0]   pcis_slr2_awregion;
   logic [3:0]   pcis_slr2_awqos;
   logic         pcis_slr2_awvalid;
   logic         pcis_slr2_awready;
   logic [511:0] pcis_slr2_wdata;
   logic [63:0]  pcis_slr2_wstrb;
   logic         pcis_slr2_wlast;
   logic         pcis_slr2_wvalid;
   logic         pcis_slr2_wready;
   logic [15:0]  pcis_slr2_bid;
   logic [1:0]   pcis_slr2_bresp;
   logic         pcis_slr2_bvalid;
   logic         pcis_slr2_bready;
   logic [15:0]  pcis_slr2_arid;
   logic [63:0]  pcis_slr2_araddr;
   logic [7:0]   pcis_slr2_arlen;
   logic [2:0]   pcis_slr2_arsize;
   logic [1:0]   pcis_slr2_arburst;
   logic [0:0]   pcis_slr2_arlock;
   logic [3:0]   pcis_slr2_arcache;
   logic [2:0]   pcis_slr2_arprot;
   logic [3:0]   pcis_slr2_arregion;
   logic [3:0]   pcis_slr2_arqos;
   logic         pcis_slr2_arvalid;
   logic         pcis_slr2_arready;
   logic [15:0]  pcis_slr2_rid;
   logic [511:0] pcis_slr2_rdata;
   logic [1:0]   pcis_slr2_rresp;
   logic         pcis_slr2_rlast;
   logic         pcis_slr2_rvalid;
   logic         pcis_slr2_rready;

   axi_register_slice AXI4_REG_SLC_PCIS_SLR2 (
      .aclk(clk),
      .aresetn(resetn),
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
      .m_axi_awid(pcis_slr2_awid),
      .m_axi_awaddr(pcis_slr2_awaddr),
      .m_axi_awlen(pcis_slr2_awlen),
      .m_axi_awsize(pcis_slr2_awsize),
      .m_axi_awburst(pcis_slr2_awburst),
      .m_axi_awlock(pcis_slr2_awlock),
      .m_axi_awcache(pcis_slr2_awcache),
      .m_axi_awprot(pcis_slr2_awprot),
      .m_axi_awregion(pcis_slr2_awregion),
      .m_axi_awqos(pcis_slr2_awqos),
      .m_axi_awvalid(pcis_slr2_awvalid),
      .m_axi_awready(pcis_slr2_awready),
      .m_axi_wdata(pcis_slr2_wdata),
      .m_axi_wstrb(pcis_slr2_wstrb),
      .m_axi_wlast(pcis_slr2_wlast),
      .m_axi_wvalid(pcis_slr2_wvalid),
      .m_axi_wready(pcis_slr2_wready),
      .m_axi_bid(pcis_slr2_bid),
      .m_axi_bresp(pcis_slr2_bresp),
      .m_axi_bvalid(pcis_slr2_bvalid),
      .m_axi_bready(pcis_slr2_bready),
      .m_axi_arid(pcis_slr2_arid),
      .m_axi_araddr(pcis_slr2_araddr),
      .m_axi_arlen(pcis_slr2_arlen),
      .m_axi_arsize(pcis_slr2_arsize),
      .m_axi_arburst(pcis_slr2_arburst),
      .m_axi_arlock(pcis_slr2_arlock),
      .m_axi_arcache(pcis_slr2_arcache),
      .m_axi_arprot(pcis_slr2_arprot),
      .m_axi_arregion(pcis_slr2_arregion),
      .m_axi_arqos(pcis_slr2_arqos),
      .m_axi_arvalid(pcis_slr2_arvalid),
      .m_axi_arready(pcis_slr2_arready),
      .m_axi_rid(pcis_slr2_rid),
      .m_axi_rdata(pcis_slr2_rdata),
      .m_axi_rresp(pcis_slr2_rresp),
      .m_axi_rlast(pcis_slr2_rlast),
      .m_axi_rvalid(pcis_slr2_rvalid),
      .m_axi_rready(pcis_slr2_rready)
   );

   axi_register_slice AXI4_REG_SLC_PCIS_SLR1 (
      .aclk(clk),
      .aresetn(resetn),
      .s_axi_awid(pcis_slr2_awid),
      .s_axi_awaddr(pcis_slr2_awaddr),
      .s_axi_awlen(pcis_slr2_awlen),
      .s_axi_awsize(pcis_slr2_awsize),
      .s_axi_awburst(pcis_slr2_awburst),
      .s_axi_awlock(pcis_slr2_awlock),
      .s_axi_awcache(pcis_slr2_awcache),
      .s_axi_awprot(pcis_slr2_awprot),
      .s_axi_awregion(pcis_slr2_awregion),
      .s_axi_awqos(pcis_slr2_awqos),
      .s_axi_awvalid(pcis_slr2_awvalid),
      .s_axi_awready(pcis_slr2_awready),
      .s_axi_wdata(pcis_slr2_wdata),
      .s_axi_wstrb(pcis_slr2_wstrb),
      .s_axi_wlast(pcis_slr2_wlast),
      .s_axi_wvalid(pcis_slr2_wvalid),
      .s_axi_wready(pcis_slr2_wready),
      .s_axi_bid(pcis_slr2_bid),
      .s_axi_bresp(pcis_slr2_bresp),
      .s_axi_bvalid(pcis_slr2_bvalid),
      .s_axi_bready(pcis_slr2_bready),
      .s_axi_arid(pcis_slr2_arid),
      .s_axi_araddr(pcis_slr2_araddr),
      .s_axi_arlen(pcis_slr2_arlen),
      .s_axi_arsize(pcis_slr2_arsize),
      .s_axi_arburst(pcis_slr2_arburst),
      .s_axi_arlock(pcis_slr2_arlock),
      .s_axi_arcache(pcis_slr2_arcache),
      .s_axi_arprot(pcis_slr2_arprot),
      .s_axi_arregion(pcis_slr2_arregion),
      .s_axi_arqos(pcis_slr2_arqos),
      .s_axi_arvalid(pcis_slr2_arvalid),
      .s_axi_arready(pcis_slr2_arready),
      .s_axi_rid(pcis_slr2_rid),
      .s_axi_rdata(pcis_slr2_rdata),
      .s_axi_rresp(pcis_slr2_rresp),
      .s_axi_rlast(pcis_slr2_rlast),
      .s_axi_rvalid(pcis_slr2_rvalid),
      .s_axi_rready(pcis_slr2_rready),
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

endmodule

module cl_firesim 

// add new enables from CL_TEMPLATE in f2
#(
   parameter EN_DDR = 1,
   parameter EN_HBM = 0
)

(
   `include "cl_ports.vh" // Fixed port definition

);

`include "cl_common_defines.vh"      // CL Defines for all examples
`include "cl_id_defines.vh"          // Defines for ID0 and ID1 (PCI ID's)
`include "cl_firesim_defines.vh" // CL Defines for cl_firesim
`include "FireSim-generated.defines.vh" // CL Defines for cl_firesim generated by firesim Makefrag

logic rst_main_n_sync;
logic rst_firesim_n_sync;
// logic rst_extra1_n_sync;

//--------------------------------------------0
// Start with Tie-Off of Unused Interfaces
//---------------------------------------------
// the developer should use the next set of `include
// to properly tie-off any unused interface
// The list is put in the top of the module
// to avoid cases where developer may forget to
// remove it from the end of the file

`include "unused_flr_template.inc"
//`include "unused_ddr_template.inc"
//`include "unused_pcim_template.inc"
`include "unused_cl_sda_template.inc"
// `include "unused_sh_bar1_template.inc" // does not exist in F2
`include "unused_apppf_irq_template.inc"
// `include "unused_sh_ocl_template.inc"
// `include "unused_dma_pcis_template.inc"

//-------------------------------------------------
// Wires
//-------------------------------------------------
//-------------------------------------------------
// ID Values (cl_hello_world_defines.vh)
//-------------------------------------------------
  assign cl_sh_id0[31:0] = `CL_SH_ID0;
  assign cl_sh_id1[31:0] = `CL_SH_ID1;

//-------------------------------------------------
// Reset Synchronization Outer
//-------------------------------------------------
logic pre_sync_rst_n;

always_ff @(negedge rst_main_n or posedge clk_main_a0)
   if (!rst_main_n)
   begin
      pre_sync_rst_n  <= 0;
      rst_main_n_sync <= 0;
   end
   else
   begin
      pre_sync_rst_n  <= 1;
      rst_main_n_sync <= pre_sync_rst_n;
   end

//---------------------------

logic firesim_internal_clock;
logic firesim_clocking_locked;

clk_wiz_0_firesim firesim_clocking (
   // Clock in ports
    .clk_in1(clk_main_a0), // input clk_in1, expects 250 mhz
    // Clock out ports
    .clk_out1(firesim_internal_clock),
    // Status and control signals
    .reset(!rst_main_n), // input reset
    .locked(firesim_clocking_locked) // output locked
);

//-------------------------------------------------
// Reset Synchronization Inner
//-------------------------------------------------
logic pre_sync_rst_n_firesim;
always_ff @(negedge rst_main_n or posedge firesim_internal_clock)
   if (!rst_main_n)
   begin
      pre_sync_rst_n_firesim  <= 0;
      rst_firesim_n_sync <= 0;
   end
   else
   begin
      pre_sync_rst_n_firesim  <= 1;
      rst_firesim_n_sync <= pre_sync_rst_n_firesim;
   end

//-------------------------------------------------
// ddr_ready synchronizer
//-------------------------------------------------
logic ddr_ready;
logic ddr_ready_pre_sync_meta, ddr_ready_sync;
always_ff @(posedge firesim_internal_clock or negedge rst_main_n) begin
   if (!rst_main_n) begin
      ddr_ready_pre_sync_meta <= 1'b0;
      ddr_ready_sync <= 1'b0;
   end else begin
      ddr_ready_pre_sync_meta <= ddr_ready;
      ddr_ready_sync <= ddr_ready_pre_sync_meta;
   end
end


//-------------------------------------------------
// PCIe OCL AXI-L (SH to CL) Timing Flops
//-------------------------------------------------

// Write address                                                                                                              
logic        sh_ocl_awvalid_q;
logic [31:0] sh_ocl_awaddr_q;
logic        ocl_sh_awready_q;
                                                                                                                           
// Write data                                                                                                                
logic        sh_ocl_wvalid_q;
logic [31:0] sh_ocl_wdata_q;
logic [ 3:0] sh_ocl_wstrb_q;
logic        ocl_sh_wready_q;
                                                                                                                           
// Write response                                                                                                            
logic        ocl_sh_bvalid_q;
logic [ 1:0] ocl_sh_bresp_q;
logic        sh_ocl_bready_q;
                                                                                                                           
// Read address                                                                                                              
logic        sh_ocl_arvalid_q;
logic [31:0] sh_ocl_araddr_q;
logic        ocl_sh_arready_q;
                                                                                                                           
// Read data/response                                                                                                        
logic        ocl_sh_rvalid_q;
logic [31:0] ocl_sh_rdata_q;
logic [ 1:0] ocl_sh_rresp_q;
logic        sh_ocl_rready_q;

interface axi_bus_t #(DATA_WIDTH=512, ADDR_WIDTH=64, ID_WIDTH=16, LEN_WIDTH=8);
    logic [ID_WIDTH-1:0]    awid;
    logic [ADDR_WIDTH-1:0]  awaddr;
    logic [LEN_WIDTH-1:0]   awlen;
    logic [2:0]             awsize;
    logic [1:0]             awburst;
    logic                   awvalid;
    logic                   awready;
    logic [DATA_WIDTH-1:0]  wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                   wlast;
    logic                   wvalid;
    logic                   wready;
    logic [ID_WIDTH-1:0]    bid;
    logic [1:0]             bresp;
    logic                   bvalid;
    logic                   bready;
    logic [ID_WIDTH-1:0]    arid;
    logic [ADDR_WIDTH-1:0]  araddr;
    logic [LEN_WIDTH-1:0]   arlen;
    logic [2:0]             arsize;
    logic [1:0]             arburst;
    logic                   arvalid;
    logic                   arready;
    logic [ID_WIDTH-1:0]    rid;
    logic [DATA_WIDTH-1:0]  rdata;
    logic [1:0]             rresp;
    logic                   rlast;
    logic                   rvalid;
    logic                   rready;
endinterface

axi_bus_t lcl_cl_sh_ddra();

// clock converter for OCL connection
axi_clock_converter_oclnew ocl_clock_convert (
  .s_axi_aclk(clk_main_a0),        // input wire s_axi_aclk
  .s_axi_aresetn(rst_main_n_sync),  // input wire s_axi_aresetn

  .s_axi_awaddr(ocl_cl_awaddr),    // input wire [31 : 0] s_axi_awaddr
  .s_axi_awprot(3'h0),             // input wire [2 : 0] s_axi_awprot
  .s_axi_awvalid(ocl_cl_awvalid),  // input wire s_axi_awvalid
  .s_axi_awready(cl_ocl_awready),  // output wire s_axi_awready
  .s_axi_wdata(ocl_cl_wdata),      // input wire [31 : 0] s_axi_wdata
  .s_axi_wstrb(ocl_cl_wstrb),      // input wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid(ocl_cl_wvalid),    // input wire s_axi_wvalid
  .s_axi_wready(cl_ocl_wready),    // output wire s_axi_wready
  .s_axi_bresp(cl_ocl_bresp),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(cl_ocl_bvalid),    // output wire s_axi_bvalid
  .s_axi_bready(ocl_cl_bready),    // input wire s_axi_bready
  .s_axi_araddr(ocl_cl_araddr),    // input wire [31 : 0] s_axi_araddr
  .s_axi_arprot(3'h0),             // input wire [2 : 0] s_axi_arprot
  .s_axi_arvalid(ocl_cl_arvalid),  // input wire s_axi_arvalid
  .s_axi_arready(cl_ocl_arready),  // output wire s_axi_arready
  .s_axi_rdata(cl_ocl_rdata),      // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp(cl_ocl_rresp),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid(cl_ocl_rvalid),    // output wire s_axi_rvalid
  .s_axi_rready(ocl_cl_rready),    // input wire s_axi_rready

  .m_axi_aclk(firesim_internal_clock),        // input wire m_axi_aclk
  .m_axi_aresetn(rst_firesim_n_sync),  // input wire m_axi_aresetn
  .m_axi_awaddr(sh_ocl_awaddr_q),    // output wire [31 : 0] m_axi_awaddr
  .m_axi_awprot(),    // output wire [2 : 0] m_axi_awprot
  .m_axi_awvalid(sh_ocl_awvalid_q),  // output wire m_axi_awvalid
  .m_axi_awready(ocl_sh_awready_q),  // input wire m_axi_awready
  .m_axi_wdata(sh_ocl_wdata_q),      // output wire [31 : 0] m_axi_wdata
  .m_axi_wstrb(sh_ocl_wstrb_q),      // output wire [3 : 0] m_axi_wstrb
  .m_axi_wvalid(sh_ocl_wvalid_q),    // output wire m_axi_wvalid
  .m_axi_wready(ocl_sh_wready_q),    // input wire m_axi_wready
  .m_axi_bresp(ocl_sh_bresp_q),      // input wire [1 : 0] m_axi_bresp
  .m_axi_bvalid(ocl_sh_bvalid_q),    // input wire m_axi_bvalid
  .m_axi_bready(sh_ocl_bready_q),    // output wire m_axi_bready
  .m_axi_araddr(sh_ocl_araddr_q),    // output wire [31 : 0] m_axi_araddr
  .m_axi_arprot(),    // output wire [2 : 0] m_axi_arprot
  .m_axi_arvalid(sh_ocl_arvalid_q),  // output wire m_axi_arvalid
  .m_axi_arready(ocl_sh_arready_q),  // input wire m_axi_arready
  .m_axi_rdata(ocl_sh_rdata_q),      // input wire [31 : 0] m_axi_rdata
  .m_axi_rresp(ocl_sh_rresp_q),      // input wire [1 : 0] m_axi_rresp
  .m_axi_rvalid(ocl_sh_rvalid_q),    // input wire m_axi_rvalid
  .m_axi_rready(sh_ocl_rready_q)    // output wire m_axi_rready
);


//-------------------------------------------------
// PCIe DMA_PCIS to FireSim Master
//-------------------------------------------------

logic [15:0] sh_cl_dma_pcis_awid_FIRESIM;
logic [63:0] sh_cl_dma_pcis_awaddr_FIRESIM;
logic [7:0] sh_cl_dma_pcis_awlen_FIRESIM;
logic [2:0] sh_cl_dma_pcis_awsize_FIRESIM;
logic sh_cl_dma_pcis_awvalid_FIRESIM;
logic cl_sh_dma_pcis_awready_FIRESIM;
logic [63:0] sh_cl_dma_pcis_wdata_FIRESIM;
logic [7:0] sh_cl_dma_pcis_wstrb_FIRESIM;
logic sh_cl_dma_pcis_wlast_FIRESIM;
logic sh_cl_dma_pcis_wvalid_FIRESIM;
logic cl_sh_dma_pcis_wready_FIRESIM;
logic [15:0] cl_sh_dma_pcis_bid_FIRESIM;
logic [1:0] cl_sh_dma_pcis_bresp_FIRESIM;
logic cl_sh_dma_pcis_bvalid_FIRESIM;
logic sh_cl_dma_pcis_bready_FIRESIM;
logic [15:0] sh_cl_dma_pcis_arid_FIRESIM;
logic [63:0] sh_cl_dma_pcis_araddr_FIRESIM;
logic [7:0] sh_cl_dma_pcis_arlen_FIRESIM;
logic [2:0] sh_cl_dma_pcis_arsize_FIRESIM;
logic sh_cl_dma_pcis_arvalid_FIRESIM;
logic cl_sh_dma_pcis_arready_FIRESIM;
logic [15:0] cl_sh_dma_pcis_rid_FIRESIM;
logic [63:0] cl_sh_dma_pcis_rdata_FIRESIM;
logic [1:0] cl_sh_dma_pcis_rresp_FIRESIM;
logic cl_sh_dma_pcis_rlast_FIRESIM;
logic cl_sh_dma_pcis_rvalid_FIRESIM;
logic sh_cl_dma_pcis_rready_FIRESIM;

logic [15:0] pcis_shell_awid_FIRESIM;
logic [63:0] pcis_shell_awaddr_FIRESIM;
logic [7:0] pcis_shell_awlen_FIRESIM;
logic [2:0] pcis_shell_awsize_FIRESIM;
logic [1:0] pcis_shell_awburst_FIRESIM;
logic [0:0] pcis_shell_awlock_FIRESIM;
logic [3:0] pcis_shell_awcache_FIRESIM;
logic [2:0] pcis_shell_awprot_FIRESIM;
logic [3:0] pcis_shell_awregion_FIRESIM;
logic [3:0] pcis_shell_awqos_FIRESIM;
logic pcis_shell_awvalid_FIRESIM;
logic pcis_shell_awready_FIRESIM;
logic [511:0] pcis_shell_wdata_FIRESIM;
logic [63:0] pcis_shell_wstrb_FIRESIM;
logic pcis_shell_wlast_FIRESIM;
logic pcis_shell_wvalid_FIRESIM;
logic pcis_shell_wready_FIRESIM;
logic [15:0] pcis_shell_bid_FIRESIM;
logic [1:0] pcis_shell_bresp_FIRESIM;
logic pcis_shell_bvalid_FIRESIM;
logic pcis_shell_bready_FIRESIM;
logic [15:0] pcis_shell_arid_FIRESIM;
logic [63:0] pcis_shell_araddr_FIRESIM;
logic [7:0] pcis_shell_arlen_FIRESIM;
logic [2:0] pcis_shell_arsize_FIRESIM;
logic [1:0] pcis_shell_arburst_FIRESIM;
logic [0:0] pcis_shell_arlock_FIRESIM;
logic [3:0] pcis_shell_arcache_FIRESIM;
logic [2:0] pcis_shell_arprot_FIRESIM;
logic [3:0] pcis_shell_arregion_FIRESIM;
logic [3:0] pcis_shell_arqos_FIRESIM;
logic pcis_shell_arvalid_FIRESIM;
logic pcis_shell_arready_FIRESIM;
logic [15:0] pcis_shell_rid_FIRESIM;
logic [511:0] pcis_shell_rdata_FIRESIM;
logic [1:0] pcis_shell_rresp_FIRESIM;
logic pcis_shell_rlast_FIRESIM;
logic pcis_shell_rvalid_FIRESIM;
logic pcis_shell_rready_FIRESIM;

logic [15:0] pcis_wide_awid_FIRESIM;
logic [63:0] pcis_wide_awaddr_FIRESIM;
logic [7:0] pcis_wide_awlen_FIRESIM;
logic [2:0] pcis_wide_awsize_FIRESIM;
logic pcis_wide_awvalid_FIRESIM;
logic pcis_wide_awready_FIRESIM;
logic [511:0] pcis_wide_wdata_FIRESIM;
logic [63:0] pcis_wide_wstrb_FIRESIM;
logic pcis_wide_wlast_FIRESIM;
logic pcis_wide_wvalid_FIRESIM;
logic pcis_wide_wready_FIRESIM;
logic [15:0] pcis_wide_bid_FIRESIM;
logic [1:0] pcis_wide_bresp_FIRESIM;
logic pcis_wide_bvalid_FIRESIM;
logic pcis_wide_bready_FIRESIM;
logic [15:0] pcis_wide_arid_FIRESIM;
logic [63:0] pcis_wide_araddr_FIRESIM;
logic [7:0] pcis_wide_arlen_FIRESIM;
logic [2:0] pcis_wide_arsize_FIRESIM;
logic pcis_wide_arvalid_FIRESIM;
logic pcis_wide_arready_FIRESIM;
logic [15:0] pcis_wide_rid_FIRESIM;
logic [511:0] pcis_wide_rdata_FIRESIM;
logic [1:0] pcis_wide_rresp_FIRESIM;
logic pcis_wide_rlast_FIRESIM;
logic pcis_wide_rvalid_FIRESIM;
logic pcis_wide_rready_FIRESIM;

logic [31:0] pcis_bridge_debug_write_state;
logic [31:0] pcis_bridge_debug_read_state;
logic [31:0] pcis_bridge_debug_wide_aw_fire_count;
logic [31:0] pcis_bridge_debug_wide_w_fire_count;
logic [31:0] pcis_bridge_debug_wide_b_fire_count;
logic [31:0] pcis_bridge_debug_narrow_aw_fire_count;
logic [31:0] pcis_bridge_debug_narrow_w_fire_count;
logic [31:0] pcis_bridge_debug_narrow_b_fire_count;
logic [31:0] pcis_bridge_debug_write_full512_count;
logic [31:0] pcis_bridge_debug_write_multilane_count;
logic [31:0] pcis_bridge_debug_write_partial_strobe_count;
logic [31:0] pcis_bridge_debug_write_zero_strobe_count;
logic [31:0] pcis_bridge_debug_write_resp_error_count;
logic [31:0] pcis_bridge_debug_wide_ar_fire_count;
logic [31:0] pcis_bridge_debug_wide_r_fire_count;
logic [31:0] pcis_bridge_debug_narrow_ar_fire_count;
logic [31:0] pcis_bridge_debug_narrow_r_fire_count;
logic [31:0] pcis_bridge_debug_read_full512_count;
logic [31:0] pcis_bridge_debug_read_multilane_count;
logic [31:0] pcis_bridge_debug_read_resp_error_count;
logic [31:0] pcis_bridge_debug_read_sub64_count;
logic [63:0] pcis_bridge_debug_last_wide_awaddr;
logic [63:0] pcis_bridge_debug_last_wide_araddr;
logic [63:0] pcis_bridge_debug_last_wide_wstrb;
logic [63:0] pcis_bridge_debug_last_narrow_wdata;
logic [63:0] pcis_bridge_debug_last_narrow_rdata;
logic [7:0] pcis_bridge_debug_last_write_lane_mask;
logic [7:0] pcis_bridge_debug_last_read_lane_mask;
logic [2:0] pcis_bridge_debug_last_write_lane;
logic [2:0] pcis_bridge_debug_last_read_lane;

assign cl_sh_dma_wr_full = 1'b0;
assign cl_sh_dma_rd_full = 1'b0;

firesim_pcis_shell_register_slice CL_DMA_PCIS_SLV (
   .clk(clk_main_a0),
   .resetn(rst_main_n_sync),

   .s_axi_awid(sh_cl_dma_pcis_awid),
   .s_axi_awaddr(sh_cl_dma_pcis_awaddr),
   .s_axi_awlen(sh_cl_dma_pcis_awlen),
   .s_axi_awsize(sh_cl_dma_pcis_awsize),
   .s_axi_awburst(2'b1),
   .s_axi_awlock(1'b0),
   .s_axi_awcache(4'h2),
   .s_axi_awprot(3'b0),
   .s_axi_awregion(4'b0),
   .s_axi_awqos(4'b0),
   .s_axi_awvalid(sh_cl_dma_pcis_awvalid),
   .s_axi_awready(cl_sh_dma_pcis_awready),
   .s_axi_wdata(sh_cl_dma_pcis_wdata),
   .s_axi_wstrb(sh_cl_dma_pcis_wstrb),
   .s_axi_wlast(sh_cl_dma_pcis_wlast),
   .s_axi_wvalid(sh_cl_dma_pcis_wvalid),
   .s_axi_wready(cl_sh_dma_pcis_wready),
   .s_axi_bid(cl_sh_dma_pcis_bid),
   .s_axi_bresp(cl_sh_dma_pcis_bresp),
   .s_axi_bvalid(cl_sh_dma_pcis_bvalid),
   .s_axi_bready(sh_cl_dma_pcis_bready),
   .s_axi_arid(sh_cl_dma_pcis_arid),
   .s_axi_araddr(sh_cl_dma_pcis_araddr),
   .s_axi_arlen(sh_cl_dma_pcis_arlen),
   .s_axi_arsize(sh_cl_dma_pcis_arsize),
   .s_axi_arburst(2'b1),
   .s_axi_arlock(1'b0),
   .s_axi_arcache(4'h2),
   .s_axi_arprot(3'b0),
   .s_axi_arregion(4'b0),
   .s_axi_arqos(4'b0),
   .s_axi_arvalid(sh_cl_dma_pcis_arvalid),
   .s_axi_arready(cl_sh_dma_pcis_arready),
   .s_axi_rid(cl_sh_dma_pcis_rid),
   .s_axi_rdata(cl_sh_dma_pcis_rdata),
   .s_axi_rresp(cl_sh_dma_pcis_rresp),
   .s_axi_rlast(cl_sh_dma_pcis_rlast),
   .s_axi_rvalid(cl_sh_dma_pcis_rvalid),
   .s_axi_rready(sh_cl_dma_pcis_rready),

   .m_axi_awid(pcis_shell_awid_FIRESIM),
   .m_axi_awaddr(pcis_shell_awaddr_FIRESIM),
   .m_axi_awlen(pcis_shell_awlen_FIRESIM),
   .m_axi_awsize(pcis_shell_awsize_FIRESIM),
   .m_axi_awburst(pcis_shell_awburst_FIRESIM),
   .m_axi_awlock(pcis_shell_awlock_FIRESIM),
   .m_axi_awcache(pcis_shell_awcache_FIRESIM),
   .m_axi_awprot(pcis_shell_awprot_FIRESIM),
   .m_axi_awregion(pcis_shell_awregion_FIRESIM),
   .m_axi_awqos(pcis_shell_awqos_FIRESIM),
   .m_axi_awvalid(pcis_shell_awvalid_FIRESIM),
   .m_axi_awready(pcis_shell_awready_FIRESIM),
   .m_axi_wdata(pcis_shell_wdata_FIRESIM),
   .m_axi_wstrb(pcis_shell_wstrb_FIRESIM),
   .m_axi_wlast(pcis_shell_wlast_FIRESIM),
   .m_axi_wvalid(pcis_shell_wvalid_FIRESIM),
   .m_axi_wready(pcis_shell_wready_FIRESIM),
   .m_axi_bid(pcis_shell_bid_FIRESIM),
   .m_axi_bresp(pcis_shell_bresp_FIRESIM),
   .m_axi_bvalid(pcis_shell_bvalid_FIRESIM),
   .m_axi_bready(pcis_shell_bready_FIRESIM),
   .m_axi_arid(pcis_shell_arid_FIRESIM),
   .m_axi_araddr(pcis_shell_araddr_FIRESIM),
   .m_axi_arlen(pcis_shell_arlen_FIRESIM),
   .m_axi_arsize(pcis_shell_arsize_FIRESIM),
   .m_axi_arburst(pcis_shell_arburst_FIRESIM),
   .m_axi_arlock(pcis_shell_arlock_FIRESIM),
   .m_axi_arcache(pcis_shell_arcache_FIRESIM),
   .m_axi_arprot(pcis_shell_arprot_FIRESIM),
   .m_axi_arregion(pcis_shell_arregion_FIRESIM),
   .m_axi_arqos(pcis_shell_arqos_FIRESIM),
   .m_axi_arvalid(pcis_shell_arvalid_FIRESIM),
   .m_axi_arready(pcis_shell_arready_FIRESIM),
   .m_axi_rid(pcis_shell_rid_FIRESIM),
   .m_axi_rdata(pcis_shell_rdata_FIRESIM),
   .m_axi_rresp(pcis_shell_rresp_FIRESIM),
   .m_axi_rlast(pcis_shell_rlast_FIRESIM),
   .m_axi_rvalid(pcis_shell_rvalid_FIRESIM),
   .m_axi_rready(pcis_shell_rready_FIRESIM)
);


axi_clock_converter_512_wide wide_pcis_clock_convert (
  .s_axi_aclk(clk_main_a0),          // input wire s_axi_aclk
  .s_axi_aresetn(rst_main_n_sync),    // input wire s_axi_aresetn

  .s_axi_awid(pcis_shell_awid_FIRESIM),          // input wire [5 : 0] s_axi_awid
  .s_axi_awaddr(pcis_shell_awaddr_FIRESIM),      // input wire [63 : 0] s_axi_awaddr
  .s_axi_awlen(pcis_shell_awlen_FIRESIM),        // input wire [7 : 0] s_axi_awlen
  .s_axi_awsize(pcis_shell_awsize_FIRESIM),      // input wire [2 : 0] s_axi_awsize
  .s_axi_awburst(pcis_shell_awburst_FIRESIM),    // input wire [1 : 0] s_axi_awburst
  .s_axi_awlock(pcis_shell_awlock_FIRESIM),      // input wire [0 : 0] s_axi_awlock
  // CACHE = xx1x indicates the transcation is modifiable and
  // that the converter should pack narrow reads into wider ones
  .s_axi_awcache(pcis_shell_awcache_FIRESIM),    // input wire [3 : 0] s_axi_awcache
  .s_axi_awprot(pcis_shell_awprot_FIRESIM),      // input wire [2 : 0] s_axi_awprot
  .s_axi_awregion(pcis_shell_awregion_FIRESIM),  // input wire [3 : 0] s_axi_awregion
  .s_axi_awqos(pcis_shell_awqos_FIRESIM),        // input wire [3 : 0] s_axi_awqos
  .s_axi_awvalid(pcis_shell_awvalid_FIRESIM),    // input wire s_axi_awvalid
  .s_axi_awready(pcis_shell_awready_FIRESIM),    // output wire s_axi_awready

  .s_axi_wdata(pcis_shell_wdata_FIRESIM),        // input wire [511 : 0] s_axi_wdata
  .s_axi_wstrb(pcis_shell_wstrb_FIRESIM),        // input wire [63 : 0] s_axi_wstrb
  .s_axi_wlast(pcis_shell_wlast_FIRESIM),        // input wire s_axi_wlast
  .s_axi_wvalid(pcis_shell_wvalid_FIRESIM),      // input wire s_axi_wvalid
  .s_axi_wready(pcis_shell_wready_FIRESIM),      // output wire s_axi_wready

  .s_axi_bid(pcis_shell_bid_FIRESIM),            // output wire [15 : 0] s_axi_bid
  .s_axi_bresp(pcis_shell_bresp_FIRESIM),        // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(pcis_shell_bvalid_FIRESIM),      // output wire s_axi_bvalid
  .s_axi_bready(pcis_shell_bready_FIRESIM),      // input wire s_axi_bready

  .s_axi_arid(pcis_shell_arid_FIRESIM),          // input wire [5 : 0] s_axi_arid
  .s_axi_araddr(pcis_shell_araddr_FIRESIM),      // input wire [63 : 0] s_axi_araddr
  .s_axi_arlen(pcis_shell_arlen_FIRESIM),        // input wire [7 : 0] s_axi_arlen
  .s_axi_arsize(pcis_shell_arsize_FIRESIM),      // input wire [2 : 0] s_axi_arsize
  .s_axi_arburst(pcis_shell_arburst_FIRESIM),    // input wire [1 : 0] s_axi_arburst
  .s_axi_arlock(pcis_shell_arlock_FIRESIM),      // input wire [0 : 0] s_axi_arlock
  // CACHE = xx1x indicates the transcation is modifiable and
  // that the converter should pack narrow reads into wider ones
  .s_axi_arcache(pcis_shell_arcache_FIRESIM),    // input wire [3 : 0] s_axi_arcache
  .s_axi_arprot(pcis_shell_arprot_FIRESIM),      // input wire [2 : 0] s_axi_arprot
  .s_axi_arregion(pcis_shell_arregion_FIRESIM),  // input wire [3 : 0] s_axi_arregion
  .s_axi_arqos(pcis_shell_arqos_FIRESIM),        // input wire [3 : 0] s_axi_arqos
  .s_axi_arvalid(pcis_shell_arvalid_FIRESIM),    // input wire s_axi_arvalid
  .s_axi_arready(pcis_shell_arready_FIRESIM),    // output wire s_axi_arready

  .s_axi_rid(pcis_shell_rid_FIRESIM),            // output wire [15 : 0] s_axi_rid
  .s_axi_rdata(pcis_shell_rdata_FIRESIM),        // output wire [511 : 0] s_axi_rdata
  .s_axi_rresp(pcis_shell_rresp_FIRESIM),        // output wire [1 : 0] s_axi_rresp
  .s_axi_rlast(pcis_shell_rlast_FIRESIM),        // output wire s_axi_rlast
  .s_axi_rvalid(pcis_shell_rvalid_FIRESIM),      // output wire s_axi_rvalid
  .s_axi_rready(pcis_shell_rready_FIRESIM),      // input wire s_axi_rready


  .m_axi_aclk(firesim_internal_clock),          // input wire m_axi_aclk
  .m_axi_aresetn(rst_firesim_n_sync),    // input wire m_axi_aresetn

  .m_axi_awid(pcis_wide_awid_FIRESIM),          // output wire [15 : 0] m_axi_awid
  .m_axi_awaddr(pcis_wide_awaddr_FIRESIM),      // output wire [63 : 0] m_axi_awaddr
  .m_axi_awlen(pcis_wide_awlen_FIRESIM),        // output wire [7 : 0] m_axi_awlen
  .m_axi_awsize(pcis_wide_awsize_FIRESIM),      // output wire [2 : 0] m_axi_awsize
  .m_axi_awburst(),    // output wire [1 : 0] m_axi_awburst
  .m_axi_awlock(),      // output wire [0 : 0] m_axi_awlock
  .m_axi_awcache(),    // output wire [3 : 0] m_axi_awcache
  .m_axi_awprot(),      // output wire [2 : 0] m_axi_awprot
  .m_axi_awregion(),  // output wire [3 : 0] m_axi_awregion
  .m_axi_awqos(),        // output wire [3 : 0] m_axi_awqos
  .m_axi_awvalid(pcis_wide_awvalid_FIRESIM),    // output wire m_axi_awvalid
  .m_axi_awready(pcis_wide_awready_FIRESIM),    // input wire m_axi_awready

  .m_axi_wdata(pcis_wide_wdata_FIRESIM),        // output wire [511 : 0] m_axi_wdata
  .m_axi_wstrb(pcis_wide_wstrb_FIRESIM),        // output wire [63 : 0] m_axi_wstrb
  .m_axi_wlast(pcis_wide_wlast_FIRESIM),        // output wire m_axi_wlast
  .m_axi_wvalid(pcis_wide_wvalid_FIRESIM),      // output wire m_axi_wvalid
  .m_axi_wready(pcis_wide_wready_FIRESIM),      // input wire m_axi_wready

  .m_axi_bid(pcis_wide_bid_FIRESIM),            // input wire [15 : 0] m_axi_bid
  .m_axi_bresp(pcis_wide_bresp_FIRESIM),        // input wire [1 : 0] m_axi_bresp
  .m_axi_bvalid(pcis_wide_bvalid_FIRESIM),      // input wire m_axi_bvalid
  .m_axi_bready(pcis_wide_bready_FIRESIM),      // output wire m_axi_bready

  .m_axi_arid(pcis_wide_arid_FIRESIM),          // output wire [15 : 0] m_axi_arid
  .m_axi_araddr(pcis_wide_araddr_FIRESIM),      // output wire [63 : 0] m_axi_araddr
  .m_axi_arlen(pcis_wide_arlen_FIRESIM),        // output wire [7 : 0] m_axi_arlen
  .m_axi_arsize(pcis_wide_arsize_FIRESIM),      // output wire [2 : 0] m_axi_arsize
  .m_axi_arburst(),    // output wire [1 : 0] m_axi_arburst
  .m_axi_arlock(),      // output wire [0 : 0] m_axi_arlock
  .m_axi_arcache(),    // output wire [3 : 0] m_axi_arcache
  .m_axi_arprot(),      // output wire [2 : 0] m_axi_arprot
  .m_axi_arregion(),  // output wire [3 : 0] m_axi_arregion
  .m_axi_arqos(),        // output wire [3 : 0] m_axi_arqos
  .m_axi_arvalid(pcis_wide_arvalid_FIRESIM),    // output wire m_axi_arvalid
  .m_axi_arready(pcis_wide_arready_FIRESIM),    // input wire m_axi_arready

  .m_axi_rid(pcis_wide_rid_FIRESIM),            // input wire [15 : 0] m_axi_rid
  .m_axi_rdata(pcis_wide_rdata_FIRESIM),        // input wire [511 : 0] m_axi_rdata
  .m_axi_rresp(pcis_wide_rresp_FIRESIM),        // input wire [1 : 0] m_axi_rresp
  .m_axi_rlast(pcis_wide_rlast_FIRESIM),        // input wire m_axi_rlast
  .m_axi_rvalid(pcis_wide_rvalid_FIRESIM),      // input wire m_axi_rvalid
  .m_axi_rready(pcis_wide_rready_FIRESIM)      // output wire m_axi_rready
);

firesim_pcis_width_bridge_512_to_64 pcis_width_bridge (
   .clk(firesim_internal_clock),
   .resetn(rst_firesim_n_sync),

   .s_axi_awid(pcis_wide_awid_FIRESIM),
   .s_axi_awaddr(pcis_wide_awaddr_FIRESIM),
   .s_axi_awlen(pcis_wide_awlen_FIRESIM),
   .s_axi_awsize(pcis_wide_awsize_FIRESIM),
   .s_axi_awvalid(pcis_wide_awvalid_FIRESIM),
   .s_axi_awready(pcis_wide_awready_FIRESIM),
   .s_axi_wdata(pcis_wide_wdata_FIRESIM),
   .s_axi_wstrb(pcis_wide_wstrb_FIRESIM),
   .s_axi_wlast(pcis_wide_wlast_FIRESIM),
   .s_axi_wvalid(pcis_wide_wvalid_FIRESIM),
   .s_axi_wready(pcis_wide_wready_FIRESIM),
   .s_axi_bid(pcis_wide_bid_FIRESIM),
   .s_axi_bresp(pcis_wide_bresp_FIRESIM),
   .s_axi_bvalid(pcis_wide_bvalid_FIRESIM),
   .s_axi_bready(pcis_wide_bready_FIRESIM),
   .s_axi_arid(pcis_wide_arid_FIRESIM),
   .s_axi_araddr(pcis_wide_araddr_FIRESIM),
   .s_axi_arlen(pcis_wide_arlen_FIRESIM),
   .s_axi_arsize(pcis_wide_arsize_FIRESIM),
   .s_axi_arvalid(pcis_wide_arvalid_FIRESIM),
   .s_axi_arready(pcis_wide_arready_FIRESIM),
   .s_axi_rid(pcis_wide_rid_FIRESIM),
   .s_axi_rdata(pcis_wide_rdata_FIRESIM),
   .s_axi_rresp(pcis_wide_rresp_FIRESIM),
   .s_axi_rlast(pcis_wide_rlast_FIRESIM),
   .s_axi_rvalid(pcis_wide_rvalid_FIRESIM),
   .s_axi_rready(pcis_wide_rready_FIRESIM),

   .m_axi_awid(sh_cl_dma_pcis_awid_FIRESIM),
   .m_axi_awaddr(sh_cl_dma_pcis_awaddr_FIRESIM),
   .m_axi_awlen(sh_cl_dma_pcis_awlen_FIRESIM),
   .m_axi_awsize(sh_cl_dma_pcis_awsize_FIRESIM),
   .m_axi_awvalid(sh_cl_dma_pcis_awvalid_FIRESIM),
   .m_axi_awready(cl_sh_dma_pcis_awready_FIRESIM),
   .m_axi_wdata(sh_cl_dma_pcis_wdata_FIRESIM),
   .m_axi_wstrb(sh_cl_dma_pcis_wstrb_FIRESIM),
   .m_axi_wlast(sh_cl_dma_pcis_wlast_FIRESIM),
   .m_axi_wvalid(sh_cl_dma_pcis_wvalid_FIRESIM),
   .m_axi_wready(cl_sh_dma_pcis_wready_FIRESIM),
   .m_axi_bid(cl_sh_dma_pcis_bid_FIRESIM),
   .m_axi_bresp(cl_sh_dma_pcis_bresp_FIRESIM),
   .m_axi_bvalid(cl_sh_dma_pcis_bvalid_FIRESIM),
   .m_axi_bready(sh_cl_dma_pcis_bready_FIRESIM),
   .m_axi_arid(sh_cl_dma_pcis_arid_FIRESIM),
   .m_axi_araddr(sh_cl_dma_pcis_araddr_FIRESIM),
   .m_axi_arlen(sh_cl_dma_pcis_arlen_FIRESIM),
   .m_axi_arsize(sh_cl_dma_pcis_arsize_FIRESIM),
   .m_axi_arvalid(sh_cl_dma_pcis_arvalid_FIRESIM),
   .m_axi_arready(cl_sh_dma_pcis_arready_FIRESIM),
   .m_axi_rid(cl_sh_dma_pcis_rid_FIRESIM),
   .m_axi_rdata(cl_sh_dma_pcis_rdata_FIRESIM),
   .m_axi_rresp(cl_sh_dma_pcis_rresp_FIRESIM),
   .m_axi_rlast(cl_sh_dma_pcis_rlast_FIRESIM),
   .m_axi_rvalid(cl_sh_dma_pcis_rvalid_FIRESIM),
   .m_axi_rready(sh_cl_dma_pcis_rready_FIRESIM),

   .debug_write_state(pcis_bridge_debug_write_state),
   .debug_read_state(pcis_bridge_debug_read_state),
   .debug_wide_aw_fire_count(pcis_bridge_debug_wide_aw_fire_count),
   .debug_wide_w_fire_count(pcis_bridge_debug_wide_w_fire_count),
   .debug_wide_b_fire_count(pcis_bridge_debug_wide_b_fire_count),
   .debug_narrow_aw_fire_count(pcis_bridge_debug_narrow_aw_fire_count),
   .debug_narrow_w_fire_count(pcis_bridge_debug_narrow_w_fire_count),
   .debug_narrow_b_fire_count(pcis_bridge_debug_narrow_b_fire_count),
   .debug_write_full512_count(pcis_bridge_debug_write_full512_count),
   .debug_write_multilane_count(pcis_bridge_debug_write_multilane_count),
   .debug_write_partial_strobe_count(pcis_bridge_debug_write_partial_strobe_count),
   .debug_write_zero_strobe_count(pcis_bridge_debug_write_zero_strobe_count),
   .debug_write_resp_error_count(pcis_bridge_debug_write_resp_error_count),
   .debug_wide_ar_fire_count(pcis_bridge_debug_wide_ar_fire_count),
   .debug_wide_r_fire_count(pcis_bridge_debug_wide_r_fire_count),
   .debug_narrow_ar_fire_count(pcis_bridge_debug_narrow_ar_fire_count),
   .debug_narrow_r_fire_count(pcis_bridge_debug_narrow_r_fire_count),
   .debug_read_full512_count(pcis_bridge_debug_read_full512_count),
   .debug_read_multilane_count(pcis_bridge_debug_read_multilane_count),
   .debug_read_resp_error_count(pcis_bridge_debug_read_resp_error_count),
   .debug_read_sub64_count(pcis_bridge_debug_read_sub64_count),
   .debug_last_wide_awaddr(pcis_bridge_debug_last_wide_awaddr),
   .debug_last_wide_araddr(pcis_bridge_debug_last_wide_araddr),
   .debug_last_wide_wstrb(pcis_bridge_debug_last_wide_wstrb),
   .debug_last_narrow_wdata(pcis_bridge_debug_last_narrow_wdata),
   .debug_last_narrow_rdata(pcis_bridge_debug_last_narrow_rdata),
   .debug_last_write_lane_mask(pcis_bridge_debug_last_write_lane_mask),
   .debug_last_read_lane_mask(pcis_bridge_debug_last_read_lane_mask),
   .debug_last_write_lane(pcis_bridge_debug_last_write_lane),
   .debug_last_read_lane(pcis_bridge_debug_last_read_lane)
);


assign cl_sh_pcim_awuser = 55'h0;
assign cl_sh_pcim_aruser = 55'h0;
assign cl_sh_pcim_awid = 0;
assign cl_sh_pcim_awaddr = 0;
assign cl_sh_pcim_awlen = 0;
assign cl_sh_pcim_awsize = 0;
assign cl_sh_pcim_awvalid = 0;
assign cl_sh_pcim_wdata = 0;
assign cl_sh_pcim_wstrb = 0;
assign cl_sh_pcim_wlast = 0;
assign cl_sh_pcim_wvalid = 0;
assign cl_sh_pcim_bready = 0;
assign cl_sh_pcim_arid = 0;
assign cl_sh_pcim_araddr = 0;
assign cl_sh_pcim_arlen = 0; 
assign cl_sh_pcim_arsize = 0;
assign cl_sh_pcim_arvalid = 0;
assign cl_sh_pcim_rready = 0;

//----------------------------------------- 
// DDR controller instantiation   
//-----------------------------------------


// Define the addition pipeline stag
// needed to close timing for the various
// place where ATG (Automatic Test Generator)
// is defined

localparam NUM_CFG_STGS_CL_DDR_ATG = 8;
localparam NUM_CFG_STGS_SH_DDR_ATG = 4;
localparam NUM_CFG_STGS_PCIE_ATG = 4;


// To reduce RTL simulation time, only 8KiB of
// each external DRAM is scrubbed in simulations

`ifdef SIM
   localparam DDR_SCRB_MAX_ADDR = 64'h1FFF;
`else   
   localparam DDR_SCRB_MAX_ADDR = 64'h3FFFFFFFF; //16GB 
`endif
   localparam DDR_SCRB_BURST_LEN_MINUS1 = 15;

`ifdef NO_CL_TST_SCRUBBER
   localparam NO_SCRB_INST = 1;
`else
   localparam NO_SCRB_INST = 0;
`endif   


logic [7:0] sh_ddr_stat_addr_q;
logic sh_ddr_stat_wr_q;
logic sh_ddr_stat_rd_q; 
logic[31:0] sh_ddr_stat_wdata_q;
logic ddr_sh_stat_ack_q;
logic[31:0] ddr_sh_stat_rdata_q;
logic[7:0] ddr_sh_stat_int_q;

logic ddr_sync_rst_n;

xpm_cdc_async_rst CDC_ASYNC_RST_N_DDR
(
  .src_arst               (rst_main_n               ),
  .dest_clk               (clk_main_a0              ),
  .dest_arst              (ddr_sync_rst_n           )
);

lib_pipe
#(
  .WIDTH                  (32                       ),
  .STAGES                 (NUM_CFG_STGS_CL_DDR_ATG  )
)
PIPE_DDR_STAT_WDATA0
(
  .clk                    (clk_main_a0              ),
  .rst_n                  (1'b1                     ),
  .in_bus                 (sh_cl_ddr_stat_wdata     ),
  .out_bus                (sh_ddr_stat_wdata_q      )
);

lib_pipe
#(
  .WIDTH                  (8                        ),
  .STAGES                 (NUM_CFG_STGS_CL_DDR_ATG  )
)
PIPE_DDR_STAT_ADDR0
(
  .clk                    (clk_main_a0              ),
  .rst_n                  (1'b1                     ),
  .in_bus                 (sh_cl_ddr_stat_addr      ),
  .out_bus                (sh_ddr_stat_addr_q       )
);

lib_pipe
#(
  .WIDTH                  (1                        ),
  .STAGES                 (NUM_CFG_STGS_CL_DDR_ATG  )
)
PIPE_DDR_STAT_WR0
(
  .clk                    (clk_main_a0              ),
  .rst_n                  (ddr_sync_rst_n           ),
  .in_bus                 (sh_cl_ddr_stat_wr        ),
  .out_bus                (sh_ddr_stat_wr_q         )
);

lib_pipe
#(
  .WIDTH                  (1                        ),
  .STAGES                 (NUM_CFG_STGS_CL_DDR_ATG  )
)
PIPE_DDR_STAT_RD0
(
  .clk                    (clk_main_a0              ),
  .rst_n                  (ddr_sync_rst_n           ),
  .in_bus                 (sh_cl_ddr_stat_rd        ),
  .out_bus                (sh_ddr_stat_rd_q         )
);

lib_pipe
#(
  .WIDTH                  (32                       ),
  .STAGES                 (NUM_CFG_STGS_CL_DDR_ATG  )
)
PIPE_DDR_STAT_ACK_RDATA0
(
  .clk                    (clk_main_a0              ),
  .rst_n                  (1'b1                     ),
  .in_bus                 (ddr_sh_stat_rdata_q      ),
  .out_bus                (cl_sh_ddr_stat_rdata     )
);

lib_pipe
#(
  .WIDTH                  (1                        ),
  .STAGES                 (NUM_CFG_STGS_CL_DDR_ATG  )
)
PIPE_DDR_STAT_ACK0
(
  .clk                    (clk_main_a0              ),
  .rst_n                  (ddr_sync_rst_n           ),
  .in_bus                 (ddr_sh_stat_ack_q        ),
  .out_bus                (cl_sh_ddr_stat_ack       )
);

lib_pipe
#(
  .WIDTH                  (8                        ),
  .STAGES                 (NUM_CFG_STGS_CL_DDR_ATG  )
)
PIPE_DDR_STAT_INT0
(
  .clk                    (clk_main_a0              ),
  .rst_n                  (ddr_sync_rst_n           ),
  .in_bus                 (ddr_sh_stat_int_q        ),
  .out_bus                (cl_sh_ddr_stat_int       )
);


logic[15:0] cl_sh_ddr_awid;
logic[63:0] cl_sh_ddr_awaddr;
logic[7:0] cl_sh_ddr_awlen;
logic[2:0] cl_sh_ddr_awsize;
logic[1:0] cl_sh_ddr_awburst;
logic cl_sh_ddr_awvalid;
logic sh_cl_ddr_awready;

logic[511:0] cl_sh_ddr_wdata;
logic[63:0] cl_sh_ddr_wstrb;
logic cl_sh_ddr_wlast;
logic cl_sh_ddr_wvalid;
logic sh_cl_ddr_wready;

logic[15:0] sh_cl_ddr_bid;
logic[1:0] sh_cl_ddr_bresp;
logic sh_cl_ddr_bvalid;
logic cl_sh_ddr_bready;

logic[15:0] cl_sh_ddr_arid;
logic[63:0] cl_sh_ddr_araddr;
logic[7:0] cl_sh_ddr_arlen;
logic[2:0] cl_sh_ddr_arsize;
logic[1:0] cl_sh_ddr_arburst;
logic cl_sh_ddr_arvalid;
logic sh_cl_ddr_arready;

logic[15:0] sh_cl_ddr_rid;
logic[511:0] sh_cl_ddr_rdata;
logic[1:0] sh_cl_ddr_rresp;
logic sh_cl_ddr_rlast;
logic sh_cl_ddr_rvalid;
logic cl_sh_ddr_rready;


assign lcl_cl_sh_ddra.awid    = cl_sh_ddr_awid;
assign lcl_cl_sh_ddra.awaddr  = cl_sh_ddr_awaddr;
assign lcl_cl_sh_ddra.awlen   = cl_sh_ddr_awlen;
assign lcl_cl_sh_ddra.awsize  = cl_sh_ddr_awsize;
assign lcl_cl_sh_ddra.awburst = cl_sh_ddr_awburst;
assign lcl_cl_sh_ddra.awvalid = cl_sh_ddr_awvalid;

assign lcl_cl_sh_ddra.wdata   = cl_sh_ddr_wdata;
assign lcl_cl_sh_ddra.wstrb   = cl_sh_ddr_wstrb;
assign lcl_cl_sh_ddra.wlast   = cl_sh_ddr_wlast;
assign lcl_cl_sh_ddra.wvalid  = cl_sh_ddr_wvalid;

assign lcl_cl_sh_ddra.bready  = cl_sh_ddr_bready;

assign lcl_cl_sh_ddra.arid    = cl_sh_ddr_arid;
assign lcl_cl_sh_ddra.araddr  = cl_sh_ddr_araddr;
assign lcl_cl_sh_ddra.arlen   = cl_sh_ddr_arlen;
assign lcl_cl_sh_ddra.arsize  = cl_sh_ddr_arsize;
assign lcl_cl_sh_ddra.arburst = cl_sh_ddr_arburst;
assign lcl_cl_sh_ddra.arvalid = cl_sh_ddr_arvalid;

assign lcl_cl_sh_ddra.rready  = cl_sh_ddr_rready;

assign sh_cl_ddr_awready = lcl_cl_sh_ddra.awready;
assign sh_cl_ddr_wready  = lcl_cl_sh_ddra.wready;

assign sh_cl_ddr_bid     = lcl_cl_sh_ddra.bid;
assign sh_cl_ddr_bresp   = lcl_cl_sh_ddra.bresp;
assign sh_cl_ddr_bvalid  = lcl_cl_sh_ddra.bvalid;

assign sh_cl_ddr_arready = lcl_cl_sh_ddra.arready;

assign sh_cl_ddr_rid     = lcl_cl_sh_ddra.rid;
assign sh_cl_ddr_rdata   = lcl_cl_sh_ddra.rdata;
assign sh_cl_ddr_rresp   = lcl_cl_sh_ddra.rresp;
assign sh_cl_ddr_rlast   = lcl_cl_sh_ddra.rlast;
assign sh_cl_ddr_rvalid  = lcl_cl_sh_ddra.rvalid;

sh_ddr
#(
  .DDR_PRESENT            (EN_DDR                   )
)
SH_DDR
(
  .clk                    (clk_main_a0              ),
  .rst_n                  (ddr_sync_rst_n           ),
  .stat_clk               (clk_main_a0              ),
  .stat_rst_n             (ddr_sync_rst_n           ),

  .CLK_DIMM_DP            (CLK_DIMM_DP              ),
  .CLK_DIMM_DN            (CLK_DIMM_DN              ),
  .M_ACT_N                (M_ACT_N                  ),
  .M_MA                   (M_MA                     ),
  .M_BA                   (M_BA                     ),
  .M_BG                   (M_BG                     ),
  .M_CKE                  (M_CKE                    ),
  .M_ODT                  (M_ODT                    ),
  .M_CS_N                 (M_CS_N                   ),
  .M_CLK_DN               (M_CLK_DN                 ),
  .M_CLK_DP               (M_CLK_DP                 ),
  .M_PAR                  (M_PAR                    ),
  .M_DQ                   (M_DQ                     ),
  .M_ECC                  (M_ECC                    ),
  .M_DQS_DP               (M_DQS_DP                 ),
  .M_DQS_DN               (M_DQS_DN                 ),
  .cl_RST_DIMM_N          (RST_DIMM_N               ),

  .cl_sh_ddr_axi_awid     (lcl_cl_sh_ddra.awid      ),
  .cl_sh_ddr_axi_awaddr   (lcl_cl_sh_ddra.awaddr    ),
  .cl_sh_ddr_axi_awlen    (lcl_cl_sh_ddra.awlen     ),
  .cl_sh_ddr_axi_awsize   (lcl_cl_sh_ddra.awsize    ),
  .cl_sh_ddr_axi_awvalid  (lcl_cl_sh_ddra.awvalid   ),
  .cl_sh_ddr_axi_awburst  (lcl_cl_sh_ddra.awburst   ),
  .cl_sh_ddr_axi_awuser   (1'd0                     ),
  .cl_sh_ddr_axi_awready  (lcl_cl_sh_ddra.awready   ),
  .cl_sh_ddr_axi_wdata    (lcl_cl_sh_ddra.wdata     ),
  .cl_sh_ddr_axi_wstrb    (lcl_cl_sh_ddra.wstrb     ),
  .cl_sh_ddr_axi_wlast    (lcl_cl_sh_ddra.wlast     ),
  .cl_sh_ddr_axi_wvalid   (lcl_cl_sh_ddra.wvalid    ),
  .cl_sh_ddr_axi_wready   (lcl_cl_sh_ddra.wready    ),
  .cl_sh_ddr_axi_bid      (lcl_cl_sh_ddra.bid       ),
  .cl_sh_ddr_axi_bresp    (lcl_cl_sh_ddra.bresp     ),
  .cl_sh_ddr_axi_bvalid   (lcl_cl_sh_ddra.bvalid    ),
  .cl_sh_ddr_axi_bready   (lcl_cl_sh_ddra.bready    ),
  .cl_sh_ddr_axi_arid     (lcl_cl_sh_ddra.arid      ),
  .cl_sh_ddr_axi_araddr   (lcl_cl_sh_ddra.araddr    ),
  .cl_sh_ddr_axi_arlen    (lcl_cl_sh_ddra.arlen     ),
  .cl_sh_ddr_axi_arsize   (lcl_cl_sh_ddra.arsize    ),
  .cl_sh_ddr_axi_arvalid  (lcl_cl_sh_ddra.arvalid   ),
  .cl_sh_ddr_axi_arburst  (lcl_cl_sh_ddra.arburst   ),
  .cl_sh_ddr_axi_aruser   (1'd0                     ),
  .cl_sh_ddr_axi_arready  (lcl_cl_sh_ddra.arready   ),
  .cl_sh_ddr_axi_rid      (lcl_cl_sh_ddra.rid       ),
  .cl_sh_ddr_axi_rdata    (lcl_cl_sh_ddra.rdata     ),
  .cl_sh_ddr_axi_rresp    (lcl_cl_sh_ddra.rresp     ),
  .cl_sh_ddr_axi_rlast    (lcl_cl_sh_ddra.rlast     ),
  .cl_sh_ddr_axi_rvalid   (lcl_cl_sh_ddra.rvalid    ),
  .cl_sh_ddr_axi_rready   (lcl_cl_sh_ddra.rready    ),

  .sh_ddr_stat_bus_addr   (sh_ddr_stat_addr_q       ),
  .sh_ddr_stat_bus_wdata  (sh_ddr_stat_wdata_q      ),
  .sh_ddr_stat_bus_wr     (sh_ddr_stat_wr_q         ),
  .sh_ddr_stat_bus_rd     (sh_ddr_stat_rd_q         ),
  .sh_ddr_stat_bus_ack    (ddr_sh_stat_ack_q        ),
  .sh_ddr_stat_bus_rdata  (ddr_sh_stat_rdata_q      ),

  .ddr_sh_stat_int        (ddr_sh_stat_int_q        ),
  .sh_cl_ddr_is_ready     (ddr_ready                )
);


//-------------------------------------------------------------------------------
//================================================================================
//------------------------------------------------------------------------------


wire [33 : 0] fsimtop_s_0_axi_awaddr_small;
wire [33 : 0] fsimtop_s_0_axi_araddr_small;

wire [15 : 0] fsimtop_s_0_axi_awid;
wire [63 : 0] fsimtop_s_0_axi_awaddr;
assign fsimtop_s_0_axi_awaddr = { 30'b0, fsimtop_s_0_axi_awaddr_small[33:0] };
wire [7 : 0] fsimtop_s_0_axi_awlen;
wire [2 : 0] fsimtop_s_0_axi_awsize;
wire [1 : 0] fsimtop_s_0_axi_awburst;
wire [0 : 0] fsimtop_s_0_axi_awlock;
wire [3 : 0] fsimtop_s_0_axi_awcache;
wire [2 : 0] fsimtop_s_0_axi_awprot;
wire [3 : 0] fsimtop_s_0_axi_awregion = 4'b0;
wire [3 : 0] fsimtop_s_0_axi_awqos;
wire fsimtop_s_0_axi_awvalid;
wire fsimtop_s_0_axi_awready;

wire [63 : 0] fsimtop_s_0_axi_wdata;
wire [7 : 0] fsimtop_s_0_axi_wstrb;
wire fsimtop_s_0_axi_wlast;
wire fsimtop_s_0_axi_wvalid;
wire fsimtop_s_0_axi_wready;

wire [15 : 0] fsimtop_s_0_axi_bid;
wire [1 : 0] fsimtop_s_0_axi_bresp;
wire fsimtop_s_0_axi_bvalid;
wire fsimtop_s_0_axi_bready;

wire [15 : 0] fsimtop_s_0_axi_arid;
wire [63 : 0] fsimtop_s_0_axi_araddr;
assign fsimtop_s_0_axi_araddr = { 30'b0, fsimtop_s_0_axi_araddr_small[33:0] };
wire [7 : 0] fsimtop_s_0_axi_arlen;
wire [2 : 0] fsimtop_s_0_axi_arsize;
wire [1 : 0] fsimtop_s_0_axi_arburst;
wire [0 : 0] fsimtop_s_0_axi_arlock;
wire [3 : 0] fsimtop_s_0_axi_arcache;
wire [2 : 0] fsimtop_s_0_axi_arprot;
wire [3 : 0] fsimtop_s_0_axi_arregion = 4'b0;
wire [3 : 0] fsimtop_s_0_axi_arqos;
wire fsimtop_s_0_axi_arvalid;
wire fsimtop_s_0_axi_arready;

wire [15 : 0] fsimtop_s_0_axi_rid;
wire [63 : 0] fsimtop_s_0_axi_rdata;
wire [1 : 0] fsimtop_s_0_axi_rresp;
wire fsimtop_s_0_axi_rlast;
wire fsimtop_s_0_axi_rvalid;
wire fsimtop_s_0_axi_rready;


wire [33 : 0] fsimtop_s_1_axi_awaddr_small;
wire [33 : 0] fsimtop_s_1_axi_araddr_small;

wire [15 : 0] fsimtop_s_1_axi_awid;
wire [63 : 0] fsimtop_s_1_axi_awaddr;
assign fsimtop_s_1_axi_awaddr = { 30'b0, fsimtop_s_1_axi_awaddr_small[33:0] };
wire [7 : 0] fsimtop_s_1_axi_awlen;
wire [2 : 0] fsimtop_s_1_axi_awsize;
wire [1 : 0] fsimtop_s_1_axi_awburst;
wire [0 : 0] fsimtop_s_1_axi_awlock;
wire [3 : 0] fsimtop_s_1_axi_awcache;
wire [2 : 0] fsimtop_s_1_axi_awprot;
wire [3 : 0] fsimtop_s_1_axi_awregion = 4'b0;
wire [3 : 0] fsimtop_s_1_axi_awqos;
wire fsimtop_s_1_axi_awvalid;
wire fsimtop_s_1_axi_awready;

wire [63 : 0] fsimtop_s_1_axi_wdata;
wire [7 : 0] fsimtop_s_1_axi_wstrb;
wire fsimtop_s_1_axi_wlast;
wire fsimtop_s_1_axi_wvalid;
wire fsimtop_s_1_axi_wready;

wire [15 : 0] fsimtop_s_1_axi_bid;
wire [1 : 0] fsimtop_s_1_axi_bresp;
wire fsimtop_s_1_axi_bvalid;
wire fsimtop_s_1_axi_bready;

wire [15 : 0] fsimtop_s_1_axi_arid;
wire [63 : 0] fsimtop_s_1_axi_araddr;
assign fsimtop_s_1_axi_araddr = { 30'b0, fsimtop_s_1_axi_araddr_small[33:0] };
wire [7 : 0] fsimtop_s_1_axi_arlen;
wire [2 : 0] fsimtop_s_1_axi_arsize;
wire [1 : 0] fsimtop_s_1_axi_arburst;
wire [0 : 0] fsimtop_s_1_axi_arlock;
wire [3 : 0] fsimtop_s_1_axi_arcache;
wire [2 : 0] fsimtop_s_1_axi_arprot;
wire [3 : 0] fsimtop_s_1_axi_arregion = 4'b0;
wire [3 : 0] fsimtop_s_1_axi_arqos;
wire fsimtop_s_1_axi_arvalid;
wire fsimtop_s_1_axi_arready;

wire [15 : 0] fsimtop_s_1_axi_rid;
wire [63 : 0] fsimtop_s_1_axi_rdata;
wire [1 : 0] fsimtop_s_1_axi_rresp;
wire fsimtop_s_1_axi_rlast;
wire fsimtop_s_1_axi_rvalid;
wire fsimtop_s_1_axi_rready;


wire [33 : 0] fsimtop_s_2_axi_awaddr_small;
wire [33 : 0] fsimtop_s_2_axi_araddr_small;

wire [15 : 0] fsimtop_s_2_axi_awid;
wire [63 : 0] fsimtop_s_2_axi_awaddr;
assign fsimtop_s_2_axi_awaddr = { 30'b0, fsimtop_s_2_axi_awaddr_small[33:0] };
wire [7 : 0] fsimtop_s_2_axi_awlen;
wire [2 : 0] fsimtop_s_2_axi_awsize;
wire [1 : 0] fsimtop_s_2_axi_awburst;
wire [0 : 0] fsimtop_s_2_axi_awlock;
wire [3 : 0] fsimtop_s_2_axi_awcache;
wire [2 : 0] fsimtop_s_2_axi_awprot;
wire [3 : 0] fsimtop_s_2_axi_awregion = 4'b0;
wire [3 : 0] fsimtop_s_2_axi_awqos;
wire fsimtop_s_2_axi_awvalid;
wire fsimtop_s_2_axi_awready;

wire [63 : 0] fsimtop_s_2_axi_wdata;
wire [7 : 0] fsimtop_s_2_axi_wstrb;
wire fsimtop_s_2_axi_wlast;
wire fsimtop_s_2_axi_wvalid;
wire fsimtop_s_2_axi_wready;

wire [15 : 0] fsimtop_s_2_axi_bid;
wire [1 : 0] fsimtop_s_2_axi_bresp;
wire fsimtop_s_2_axi_bvalid;
wire fsimtop_s_2_axi_bready;

wire [15 : 0] fsimtop_s_2_axi_arid;
wire [63 : 0] fsimtop_s_2_axi_araddr;
assign fsimtop_s_2_axi_araddr = { 30'b0, fsimtop_s_2_axi_araddr_small[33:0] };
wire [7 : 0] fsimtop_s_2_axi_arlen;
wire [2 : 0] fsimtop_s_2_axi_arsize;
wire [1 : 0] fsimtop_s_2_axi_arburst;
wire [0 : 0] fsimtop_s_2_axi_arlock;
wire [3 : 0] fsimtop_s_2_axi_arcache;
wire [2 : 0] fsimtop_s_2_axi_arprot;
wire [3 : 0] fsimtop_s_2_axi_arregion = 4'b0;
wire [3 : 0] fsimtop_s_2_axi_arqos;
wire fsimtop_s_2_axi_arvalid;
wire fsimtop_s_2_axi_arready;

wire [15 : 0] fsimtop_s_2_axi_rid;
wire [63 : 0] fsimtop_s_2_axi_rdata;
wire [1 : 0] fsimtop_s_2_axi_rresp;
wire fsimtop_s_2_axi_rlast;
wire fsimtop_s_2_axi_rvalid;
wire fsimtop_s_2_axi_rready;



wire [33 : 0] fsimtop_s_3_axi_awaddr_small;
wire [33 : 0] fsimtop_s_3_axi_araddr_small;

wire [15 : 0] fsimtop_s_3_axi_awid;
wire [63 : 0] fsimtop_s_3_axi_awaddr;
assign fsimtop_s_3_axi_awaddr = { 30'b0, fsimtop_s_3_axi_awaddr_small[33:0] };
wire [7 : 0] fsimtop_s_3_axi_awlen;
wire [2 : 0] fsimtop_s_3_axi_awsize;
wire [1 : 0] fsimtop_s_3_axi_awburst;
wire [0 : 0] fsimtop_s_3_axi_awlock;
wire [3 : 0] fsimtop_s_3_axi_awcache;
wire [2 : 0] fsimtop_s_3_axi_awprot;
wire [3 : 0] fsimtop_s_3_axi_awregion = 4'b0;
wire [3 : 0] fsimtop_s_3_axi_awqos;
wire fsimtop_s_3_axi_awvalid;
wire fsimtop_s_3_axi_awready;

wire [63 : 0] fsimtop_s_3_axi_wdata;
wire [7 : 0] fsimtop_s_3_axi_wstrb;
wire fsimtop_s_3_axi_wlast;
wire fsimtop_s_3_axi_wvalid;
wire fsimtop_s_3_axi_wready;

wire [15 : 0] fsimtop_s_3_axi_bid;
wire [1 : 0] fsimtop_s_3_axi_bresp;
wire fsimtop_s_3_axi_bvalid;
wire fsimtop_s_3_axi_bready;

wire [15 : 0] fsimtop_s_3_axi_arid;
wire [63 : 0] fsimtop_s_3_axi_araddr;
assign fsimtop_s_3_axi_araddr = { 30'b0, fsimtop_s_3_axi_araddr_small[33:0] };
wire [7 : 0] fsimtop_s_3_axi_arlen;
wire [2 : 0] fsimtop_s_3_axi_arsize;
wire [1 : 0] fsimtop_s_3_axi_arburst;
wire [0 : 0] fsimtop_s_3_axi_arlock;
wire [3 : 0] fsimtop_s_3_axi_arcache;
wire [2 : 0] fsimtop_s_3_axi_arprot;
wire [3 : 0] fsimtop_s_3_axi_arregion = 4'b0;
wire [3 : 0] fsimtop_s_3_axi_arqos;
wire fsimtop_s_3_axi_arvalid;
wire fsimtop_s_3_axi_arready;

wire [15 : 0] fsimtop_s_3_axi_rid;
wire [63 : 0] fsimtop_s_3_axi_rdata;
wire [1 : 0] fsimtop_s_3_axi_rresp;
wire fsimtop_s_3_axi_rlast;
wire fsimtop_s_3_axi_rvalid;
wire fsimtop_s_3_axi_rready;


F1Shim firesim_top (
   .clock(firesim_internal_clock),
   .reset(!rst_firesim_n_sync),
   .io_master_aw_ready(ocl_sh_awready_q),
   .io_master_aw_valid(sh_ocl_awvalid_q),
   .io_master_aw_bits_addr(sh_ocl_awaddr_q[24:0]),
   .io_master_aw_bits_len(8'h0),
   .io_master_aw_bits_size(3'h2),
   .io_master_aw_bits_burst(2'h1),
   .io_master_aw_bits_lock(1'h0),
   .io_master_aw_bits_cache(4'h0),
   .io_master_aw_bits_prot(3'h0), //unused? (could connect?)
   .io_master_aw_bits_qos(4'h0),
   .io_master_aw_bits_region(4'h0),
   .io_master_aw_bits_id(12'h0),
   .io_master_aw_bits_user(1'h0),
   .io_master_w_ready(ocl_sh_wready_q),
   .io_master_w_valid(sh_ocl_wvalid_q),
   .io_master_w_bits_data(sh_ocl_wdata_q),
   .io_master_w_bits_last(1'h1),
   .io_master_w_bits_id(12'h0),
   .io_master_w_bits_strb(sh_ocl_wstrb_q), //OR 8'hff
   .io_master_w_bits_user(1'h0),
   .io_master_b_ready(sh_ocl_bready_q),
   .io_master_b_valid(ocl_sh_bvalid_q),
   .io_master_b_bits_resp(ocl_sh_bresp_q),
   .io_master_b_bits_id(),      // UNUSED at top level
   .io_master_b_bits_user(),    // UNUSED at top level
   .io_master_ar_ready(ocl_sh_arready_q),
   .io_master_ar_valid(sh_ocl_arvalid_q),
   .io_master_ar_bits_addr(sh_ocl_araddr_q[24:0]),
   .io_master_ar_bits_len(8'h0),
   .io_master_ar_bits_size(3'h2),
   .io_master_ar_bits_burst(2'h1),
   .io_master_ar_bits_lock(1'h0),
   .io_master_ar_bits_cache(4'h0),
   .io_master_ar_bits_prot(3'h0),
   .io_master_ar_bits_qos(4'h0),
   .io_master_ar_bits_region(4'h0),
   .io_master_ar_bits_id(12'h0),
   .io_master_ar_bits_user(1'h0),
   .io_master_r_ready(sh_ocl_rready_q),
   .io_master_r_valid(ocl_sh_rvalid_q),
   .io_master_r_bits_resp(ocl_sh_rresp_q),
   .io_master_r_bits_data(ocl_sh_rdata_q),
   .io_master_r_bits_last(), //UNUSED at top level
   .io_master_r_bits_id(),      // UNUSED at top level
   .io_master_r_bits_user(),    // UNUSED at top level

   // special NIC master interface
   .io_pcis_aw_ready(cl_sh_dma_pcis_awready_FIRESIM),
   .io_pcis_aw_valid(sh_cl_dma_pcis_awvalid_FIRESIM),
   .io_pcis_aw_bits_addr(sh_cl_dma_pcis_awaddr_FIRESIM),
   .io_pcis_aw_bits_len(sh_cl_dma_pcis_awlen_FIRESIM),
   .io_pcis_aw_bits_size(sh_cl_dma_pcis_awsize_FIRESIM),
   .io_pcis_aw_bits_burst(2'h1),
   .io_pcis_aw_bits_lock(1'h0),
   .io_pcis_aw_bits_cache(4'h0),
   .io_pcis_aw_bits_prot(3'h0), //unused? (could connect?)
   .io_pcis_aw_bits_qos(4'h0),
   .io_pcis_aw_bits_region(4'h0),
   .io_pcis_aw_bits_id(sh_cl_dma_pcis_awid_FIRESIM),
   .io_pcis_aw_bits_user(1'h0),
   .io_pcis_w_ready(cl_sh_dma_pcis_wready_FIRESIM),
   .io_pcis_w_valid(sh_cl_dma_pcis_wvalid_FIRESIM),
   .io_pcis_w_bits_data(sh_cl_dma_pcis_wdata_FIRESIM),
   .io_pcis_w_bits_last(sh_cl_dma_pcis_wlast_FIRESIM),
   .io_pcis_w_bits_id(16'h0),
   .io_pcis_w_bits_strb(sh_cl_dma_pcis_wstrb_FIRESIM),
   .io_pcis_w_bits_user(1'h0),
   .io_pcis_b_ready(sh_cl_dma_pcis_bready_FIRESIM),
   .io_pcis_b_valid(cl_sh_dma_pcis_bvalid_FIRESIM),
   .io_pcis_b_bits_resp(cl_sh_dma_pcis_bresp_FIRESIM),
   .io_pcis_b_bits_id(cl_sh_dma_pcis_bid_FIRESIM),
   .io_pcis_b_bits_user(),    // UNUSED at top level
   .io_pcis_ar_ready(cl_sh_dma_pcis_arready_FIRESIM),
   .io_pcis_ar_valid(sh_cl_dma_pcis_arvalid_FIRESIM),
   .io_pcis_ar_bits_addr(sh_cl_dma_pcis_araddr_FIRESIM),
   .io_pcis_ar_bits_len(sh_cl_dma_pcis_arlen_FIRESIM),
   .io_pcis_ar_bits_size(sh_cl_dma_pcis_arsize_FIRESIM),
   .io_pcis_ar_bits_burst(2'h1),
   .io_pcis_ar_bits_lock(1'h0),
   .io_pcis_ar_bits_cache(4'h0),
   .io_pcis_ar_bits_prot(3'h0),
   .io_pcis_ar_bits_qos(4'h0),
   .io_pcis_ar_bits_region(4'h0),
   .io_pcis_ar_bits_id(sh_cl_dma_pcis_arid_FIRESIM),
   .io_pcis_ar_bits_user(1'h0),
   .io_pcis_r_ready(sh_cl_dma_pcis_rready_FIRESIM),
   .io_pcis_r_valid(cl_sh_dma_pcis_rvalid_FIRESIM),
   .io_pcis_r_bits_resp(cl_sh_dma_pcis_rresp_FIRESIM),
   .io_pcis_r_bits_data(cl_sh_dma_pcis_rdata_FIRESIM),
   .io_pcis_r_bits_last(cl_sh_dma_pcis_rlast_FIRESIM),
   .io_pcis_r_bits_id(cl_sh_dma_pcis_rid_FIRESIM),
   .io_pcis_r_bits_user(),    // UNUSED at top level

   // .io_pcim_aw_ready(sh_cl_pcim_awready_FIRESIM),
   // .io_pcim_aw_valid(cl_sh_pcim_awvalid_FIRESIM),
   // .io_pcim_aw_bits_addr(cl_sh_pcim_awaddr_FIRESIM),
   // .io_pcim_aw_bits_len(cl_sh_pcim_awlen_FIRESIM),
   // .io_pcim_aw_bits_size(cl_sh_pcim_awsize_FIRESIM),
   // .io_pcim_aw_bits_burst(),
   // .io_pcim_aw_bits_lock(),
   // .io_pcim_aw_bits_cache(),
   // .io_pcim_aw_bits_prot(),
   // .io_pcim_aw_bits_qos(),
   // .io_pcim_aw_bits_region(),
   // .io_pcim_aw_bits_id(cl_sh_pcim_awid_FIRESIM),
   // .io_pcim_aw_bits_user(),
   // .io_pcim_w_ready(sh_cl_pcim_wready_FIRESIM),
   // .io_pcim_w_valid(cl_sh_pcim_wvalid_FIRESIM),
   // .io_pcim_w_bits_data(cl_sh_pcim_wdata_FIRESIM),
   // .io_pcim_w_bits_last(cl_sh_pcim_wlast_FIRESIM),
   // .io_pcim_w_bits_id(),
   // .io_pcim_w_bits_strb(cl_sh_pcim_wstrb_FIRESIM),
   // .io_pcim_w_bits_user(),
   // .io_pcim_b_ready(cl_sh_pcim_bready_FIRESIM),
   // .io_pcim_b_valid(sh_cl_pcim_bvalid_FIRESIM),
   // .io_pcim_b_bits_resp(sh_cl_pcim_bresp_FIRESIM),
   // .io_pcim_b_bits_id(sh_cl_pcim_bid_FIRESIM),
   // .io_pcim_b_bits_user(1'h0),
   // .io_pcim_ar_ready(sh_cl_pcim_arready_FIRESIM),
   // .io_pcim_ar_valid(cl_sh_pcim_arvalid_FIRESIM),
   // .io_pcim_ar_bits_addr(cl_sh_pcim_araddr_FIRESIM),
   // .io_pcim_ar_bits_len(cl_sh_pcim_arlen_FIRESIM),
   // .io_pcim_ar_bits_size(cl_sh_pcim_arsize_FIRESIM),
   // .io_pcim_ar_bits_burst(),
   // .io_pcim_ar_bits_lock(),
   // .io_pcim_ar_bits_cache(),
   // .io_pcim_ar_bits_prot(),
   // .io_pcim_ar_bits_qos(),
   // .io_pcim_ar_bits_region(),
   // .io_pcim_ar_bits_id(cl_sh_pcim_arid_FIRESIM),
   // .io_pcim_ar_bits_user(),
   // .io_pcim_r_ready(cl_sh_pcim_rready_FIRESIM),
   // .io_pcim_r_valid(sh_cl_pcim_rvalid_FIRESIM),
   // .io_pcim_r_bits_resp(sh_cl_pcim_rresp_FIRESIM),
   // .io_pcim_r_bits_data(sh_cl_pcim_rdata_FIRESIM),
   // .io_pcim_r_bits_last(sh_cl_pcim_rlast_FIRESIM),
   // .io_pcim_r_bits_id(sh_cl_pcim_rid_FIRESIM),
   // .io_pcim_r_bits_user(1'h0),

   .io_slave_0_aw_ready(fsimtop_s_0_axi_awready),
   .io_slave_0_aw_valid(fsimtop_s_0_axi_awvalid),
   .io_slave_0_aw_bits_addr(fsimtop_s_0_axi_awaddr_small),
   .io_slave_0_aw_bits_len(fsimtop_s_0_axi_awlen),
   .io_slave_0_aw_bits_size(fsimtop_s_0_axi_awsize),
   .io_slave_0_aw_bits_burst(fsimtop_s_0_axi_awburst), // not available on DDR IF
   .io_slave_0_aw_bits_lock(fsimtop_s_0_axi_awlock), // not available on DDR IF
   .io_slave_0_aw_bits_cache(fsimtop_s_0_axi_awcache), // not available on DDR IF
   .io_slave_0_aw_bits_prot(fsimtop_s_0_axi_awprot), // not available on DDR IF
   .io_slave_0_aw_bits_qos(fsimtop_s_0_axi_awqos), // not available on DDR IF
   .io_slave_0_aw_bits_id(fsimtop_s_0_axi_awid),

   .io_slave_0_w_ready(fsimtop_s_0_axi_wready),
   .io_slave_0_w_valid(fsimtop_s_0_axi_wvalid),
   .io_slave_0_w_bits_data(fsimtop_s_0_axi_wdata),
   .io_slave_0_w_bits_last(fsimtop_s_0_axi_wlast),
   .io_slave_0_w_bits_strb(fsimtop_s_0_axi_wstrb),

   .io_slave_0_b_ready(fsimtop_s_0_axi_bready),
   .io_slave_0_b_valid(fsimtop_s_0_axi_bvalid),
   .io_slave_0_b_bits_resp(fsimtop_s_0_axi_bresp),
   .io_slave_0_b_bits_id(fsimtop_s_0_axi_bid),

   .io_slave_0_ar_ready(fsimtop_s_0_axi_arready),
   .io_slave_0_ar_valid(fsimtop_s_0_axi_arvalid),
   .io_slave_0_ar_bits_addr(fsimtop_s_0_axi_araddr_small),
   .io_slave_0_ar_bits_len(fsimtop_s_0_axi_arlen),
   .io_slave_0_ar_bits_size(fsimtop_s_0_axi_arsize),
   .io_slave_0_ar_bits_burst(fsimtop_s_0_axi_arburst), // not available on DDR IF
   .io_slave_0_ar_bits_lock(fsimtop_s_0_axi_arlock), // not available on DDR IF
   .io_slave_0_ar_bits_cache(fsimtop_s_0_axi_arcache), // not available on DDR IF
   .io_slave_0_ar_bits_prot(fsimtop_s_0_axi_arprot), // not available on DDR IF
   .io_slave_0_ar_bits_qos(fsimtop_s_0_axi_arqos), // not available on DDR IF
   .io_slave_0_ar_bits_id(fsimtop_s_0_axi_arid), // not available on DDR IF

   .io_slave_0_r_ready(fsimtop_s_0_axi_rready),
   .io_slave_0_r_valid(fsimtop_s_0_axi_rvalid),
   .io_slave_0_r_bits_resp(fsimtop_s_0_axi_rresp),
   .io_slave_0_r_bits_data(fsimtop_s_0_axi_rdata),
   .io_slave_0_r_bits_last(fsimtop_s_0_axi_rlast),
   .io_slave_0_r_bits_id(fsimtop_s_0_axi_rid),

   .io_slave_1_aw_ready(fsimtop_s_1_axi_awready),
   .io_slave_1_aw_valid(fsimtop_s_1_axi_awvalid),
   .io_slave_1_aw_bits_addr(fsimtop_s_1_axi_awaddr_small),
   .io_slave_1_aw_bits_len(fsimtop_s_1_axi_awlen),
   .io_slave_1_aw_bits_size(fsimtop_s_1_axi_awsize),
   .io_slave_1_aw_bits_burst(fsimtop_s_1_axi_awburst), // not available on DDR IF
   .io_slave_1_aw_bits_lock(fsimtop_s_1_axi_awlock), // not available on DDR IF
   .io_slave_1_aw_bits_cache(fsimtop_s_1_axi_awcache), // not available on DDR IF
   .io_slave_1_aw_bits_prot(fsimtop_s_1_axi_awprot), // not available on DDR IF
   .io_slave_1_aw_bits_qos(fsimtop_s_1_axi_awqos), // not available on DDR IF
   .io_slave_1_aw_bits_id(fsimtop_s_1_axi_awid),

   .io_slave_1_w_ready(fsimtop_s_1_axi_wready),
   .io_slave_1_w_valid(fsimtop_s_1_axi_wvalid),
   .io_slave_1_w_bits_data(fsimtop_s_1_axi_wdata),
   .io_slave_1_w_bits_last(fsimtop_s_1_axi_wlast),
   .io_slave_1_w_bits_strb(fsimtop_s_1_axi_wstrb),

   .io_slave_1_b_ready(fsimtop_s_1_axi_bready),
   .io_slave_1_b_valid(fsimtop_s_1_axi_bvalid),
   .io_slave_1_b_bits_resp(fsimtop_s_1_axi_bresp),
   .io_slave_1_b_bits_id(fsimtop_s_1_axi_bid),

   .io_slave_1_ar_ready(fsimtop_s_1_axi_arready),
   .io_slave_1_ar_valid(fsimtop_s_1_axi_arvalid),
   .io_slave_1_ar_bits_addr(fsimtop_s_1_axi_araddr_small),
   .io_slave_1_ar_bits_len(fsimtop_s_1_axi_arlen),
   .io_slave_1_ar_bits_size(fsimtop_s_1_axi_arsize),
   .io_slave_1_ar_bits_burst(fsimtop_s_1_axi_arburst), // not available on DDR IF
   .io_slave_1_ar_bits_lock(fsimtop_s_1_axi_arlock), // not available on DDR IF
   .io_slave_1_ar_bits_cache(fsimtop_s_1_axi_arcache), // not available on DDR IF
   .io_slave_1_ar_bits_prot(fsimtop_s_1_axi_arprot), // not available on DDR IF
   .io_slave_1_ar_bits_qos(fsimtop_s_1_axi_arqos), // not available on DDR IF
   .io_slave_1_ar_bits_id(fsimtop_s_1_axi_arid), // not available on DDR IF

   .io_slave_1_r_ready(fsimtop_s_1_axi_rready),
   .io_slave_1_r_valid(fsimtop_s_1_axi_rvalid),
   .io_slave_1_r_bits_resp(fsimtop_s_1_axi_rresp),
   .io_slave_1_r_bits_data(fsimtop_s_1_axi_rdata),
   .io_slave_1_r_bits_last(fsimtop_s_1_axi_rlast),
   .io_slave_1_r_bits_id(fsimtop_s_1_axi_rid),

   .io_slave_2_aw_ready(fsimtop_s_2_axi_awready),
   .io_slave_2_aw_valid(fsimtop_s_2_axi_awvalid),
   .io_slave_2_aw_bits_addr(fsimtop_s_2_axi_awaddr_small),
   .io_slave_2_aw_bits_len(fsimtop_s_2_axi_awlen),
   .io_slave_2_aw_bits_size(fsimtop_s_2_axi_awsize),
   .io_slave_2_aw_bits_burst(fsimtop_s_2_axi_awburst), // not available on DDR IF
   .io_slave_2_aw_bits_lock(fsimtop_s_2_axi_awlock), // not available on DDR IF
   .io_slave_2_aw_bits_cache(fsimtop_s_2_axi_awcache), // not available on DDR IF
   .io_slave_2_aw_bits_prot(fsimtop_s_2_axi_awprot), // not available on DDR IF
   .io_slave_2_aw_bits_qos(fsimtop_s_2_axi_awqos), // not available on DDR IF
   .io_slave_2_aw_bits_id(fsimtop_s_2_axi_awid),

   .io_slave_2_w_ready(fsimtop_s_2_axi_wready),
   .io_slave_2_w_valid(fsimtop_s_2_axi_wvalid),
   .io_slave_2_w_bits_data(fsimtop_s_2_axi_wdata),
   .io_slave_2_w_bits_last(fsimtop_s_2_axi_wlast),
   .io_slave_2_w_bits_strb(fsimtop_s_2_axi_wstrb),

   .io_slave_2_b_ready(fsimtop_s_2_axi_bready),
   .io_slave_2_b_valid(fsimtop_s_2_axi_bvalid),
   .io_slave_2_b_bits_resp(fsimtop_s_2_axi_bresp),
   .io_slave_2_b_bits_id(fsimtop_s_2_axi_bid),

   .io_slave_2_ar_ready(fsimtop_s_2_axi_arready),
   .io_slave_2_ar_valid(fsimtop_s_2_axi_arvalid),
   .io_slave_2_ar_bits_addr(fsimtop_s_2_axi_araddr_small),
   .io_slave_2_ar_bits_len(fsimtop_s_2_axi_arlen),
   .io_slave_2_ar_bits_size(fsimtop_s_2_axi_arsize),
   .io_slave_2_ar_bits_burst(fsimtop_s_2_axi_arburst), // not available on DDR IF
   .io_slave_2_ar_bits_lock(fsimtop_s_2_axi_arlock), // not available on DDR IF
   .io_slave_2_ar_bits_cache(fsimtop_s_2_axi_arcache), // not available on DDR IF
   .io_slave_2_ar_bits_prot(fsimtop_s_2_axi_arprot), // not available on DDR IF
   .io_slave_2_ar_bits_qos(fsimtop_s_2_axi_arqos), // not available on DDR IF
   .io_slave_2_ar_bits_id(fsimtop_s_2_axi_arid), // not available on DDR IF

   .io_slave_2_r_ready(fsimtop_s_2_axi_rready),
   .io_slave_2_r_valid(fsimtop_s_2_axi_rvalid),
   .io_slave_2_r_bits_resp(fsimtop_s_2_axi_rresp),
   .io_slave_2_r_bits_data(fsimtop_s_2_axi_rdata),
   .io_slave_2_r_bits_last(fsimtop_s_2_axi_rlast),
   .io_slave_2_r_bits_id(fsimtop_s_2_axi_rid),

   .io_slave_3_aw_ready(fsimtop_s_3_axi_awready),
   .io_slave_3_aw_valid(fsimtop_s_3_axi_awvalid),
   .io_slave_3_aw_bits_addr(fsimtop_s_3_axi_awaddr_small),
   .io_slave_3_aw_bits_len(fsimtop_s_3_axi_awlen),
   .io_slave_3_aw_bits_size(fsimtop_s_3_axi_awsize),
   .io_slave_3_aw_bits_burst(fsimtop_s_3_axi_awburst), // not available on DDR IF
   .io_slave_3_aw_bits_lock(fsimtop_s_3_axi_awlock), // not available on DDR IF
   .io_slave_3_aw_bits_cache(fsimtop_s_3_axi_awcache), // not available on DDR IF
   .io_slave_3_aw_bits_prot(fsimtop_s_3_axi_awprot), // not available on DDR IF
   .io_slave_3_aw_bits_qos(fsimtop_s_3_axi_awqos), // not available on DDR IF
   .io_slave_3_aw_bits_id(fsimtop_s_3_axi_awid),

   .io_slave_3_w_ready(fsimtop_s_3_axi_wready),
   .io_slave_3_w_valid(fsimtop_s_3_axi_wvalid),
   .io_slave_3_w_bits_data(fsimtop_s_3_axi_wdata),
   .io_slave_3_w_bits_last(fsimtop_s_3_axi_wlast),
   .io_slave_3_w_bits_strb(fsimtop_s_3_axi_wstrb),

   .io_slave_3_b_ready(fsimtop_s_3_axi_bready),
   .io_slave_3_b_valid(fsimtop_s_3_axi_bvalid),
   .io_slave_3_b_bits_resp(fsimtop_s_3_axi_bresp),
   .io_slave_3_b_bits_id(fsimtop_s_3_axi_bid),

   .io_slave_3_ar_ready(fsimtop_s_3_axi_arready),
   .io_slave_3_ar_valid(fsimtop_s_3_axi_arvalid),
   .io_slave_3_ar_bits_addr(fsimtop_s_3_axi_araddr_small),
   .io_slave_3_ar_bits_len(fsimtop_s_3_axi_arlen),
   .io_slave_3_ar_bits_size(fsimtop_s_3_axi_arsize),
   .io_slave_3_ar_bits_burst(fsimtop_s_3_axi_arburst), // not available on DDR IF
   .io_slave_3_ar_bits_lock(fsimtop_s_3_axi_arlock), // not available on DDR IF
   .io_slave_3_ar_bits_cache(fsimtop_s_3_axi_arcache), // not available on DDR IF
   .io_slave_3_ar_bits_prot(fsimtop_s_3_axi_arprot), // not available on DDR IF
   .io_slave_3_ar_bits_qos(fsimtop_s_3_axi_arqos), // not available on DDR IF
   .io_slave_3_ar_bits_id(fsimtop_s_3_axi_arid), // not available on DDR IF

   .io_slave_3_r_ready(fsimtop_s_3_axi_rready),
   .io_slave_3_r_valid(fsimtop_s_3_axi_rvalid),
   .io_slave_3_r_bits_resp(fsimtop_s_3_axi_rresp),
   .io_slave_3_r_bits_data(fsimtop_s_3_axi_rdata),
   .io_slave_3_r_bits_last(fsimtop_s_3_axi_rlast),
   .io_slave_3_r_bits_id(fsimtop_s_3_axi_rid)
);

  // assign cl_sh_ddr_awsize = 3'b110;
  // assign cl_sh_ddr_arsize = 3'b110;
  //assert ((cl_sh_ddr_awsize == 3'b110) | (!cl_sh_ddr_awvalid)) else $error("INVALID AWSIZE on DRAM IF");
  //assert ((cl_sh_ddr_arsize == 3'b110) | (!cl_sh_ddr_arvalid)) else $error("INVALID ARSIZE on DRAM IF");

  // this is fine.
//   assign cl_sh_ddr_wid = 16'b0; // OK. not sure why this signal is exposed



//****************DDR CHANNEL C****************************

wire [15 : 0] clock_converted_axi_0_awid;
wire [63 : 0] clock_converted_axi_0_awaddr;
wire [7 : 0]  clock_converted_axi_0_awlen;
wire [2 : 0]  clock_converted_axi_0_awsize;
wire [1 : 0]  clock_converted_axi_0_awburst;
wire [0 : 0]  clock_converted_axi_0_awlock;
wire [3 : 0]  clock_converted_axi_0_awcache;
wire [2 : 0]  clock_converted_axi_0_awprot;
wire [3 : 0]  clock_converted_axi_0_awregion;
wire [3 : 0]  clock_converted_axi_0_awqos;
wire          clock_converted_axi_0_awvalid;
wire          clock_converted_axi_0_awready;

wire [63 : 0] clock_converted_axi_0_wdata;
wire [7 : 0]  clock_converted_axi_0_wstrb;
wire          clock_converted_axi_0_wlast;
wire          clock_converted_axi_0_wvalid;
wire          clock_converted_axi_0_wready;

wire [15 : 0] clock_converted_axi_0_bid;
wire [1 : 0]  clock_converted_axi_0_bresp;
wire          clock_converted_axi_0_bvalid;
wire          clock_converted_axi_0_bready;

wire [15 : 0] clock_converted_axi_0_arid;
wire [63 : 0] clock_converted_axi_0_araddr;
wire [7 : 0]  clock_converted_axi_0_arlen;
wire [2 : 0]  clock_converted_axi_0_arsize;
wire [1 : 0]  clock_converted_axi_0_arburst;
wire [0 : 0]  clock_converted_axi_0_arlock;
wire [3 : 0]  clock_converted_axi_0_arcache;
wire [2 : 0]  clock_converted_axi_0_arprot;
wire [3 : 0]  clock_converted_axi_0_arregion;
wire [3 : 0]  clock_converted_axi_0_arqos;
wire          clock_converted_axi_0_arvalid;
wire          clock_converted_axi_0_arready;

wire [15 : 0] clock_converted_axi_0_rid;
wire [63 : 0] clock_converted_axi_0_rdata;
wire [1 : 0]  clock_converted_axi_0_rresp;
wire          clock_converted_axi_0_rlast;
wire          clock_converted_axi_0_rvalid;
wire          clock_converted_axi_0_rready;

axi_clock_converter_dramslim clock_convert_dramslim_0 (
   .s_axi_aclk(firesim_internal_clock),          // input wire s_axi_aclk
   .s_axi_aresetn(rst_firesim_n_sync),    // input wire s_axi_aresetn

   .s_axi_awid(fsimtop_s_0_axi_awid),          // input wire [15 : 0] s_axi_awid
   .s_axi_awaddr(fsimtop_s_0_axi_awaddr),      // input wire [63 : 0] s_axi_awaddr
   .s_axi_awlen(fsimtop_s_0_axi_awlen),        // input wire [7 : 0] s_axi_awlen
   .s_axi_awsize(fsimtop_s_0_axi_awsize),      // input wire [2 : 0] s_axi_awsize
   .s_axi_awburst(fsimtop_s_0_axi_awburst),    // input wire [1 : 0] s_axi_awburst
   .s_axi_awlock(fsimtop_s_0_axi_awlock),      // input wire [0 : 0] s_axi_awlock
   // CACHE = xx1x indicates the transcation is modifiable and
   // that the converter should pack narrow writes into wider ones
   .s_axi_awcache(4'h2),    // input wire [3 : 0] s_axi_awcache
   .s_axi_awprot(fsimtop_s_0_axi_awprot),      // input wire [2 : 0] s_axi_awprot
   .s_axi_awregion(fsimtop_s_0_axi_awregion),  // input wire [3 : 0] s_axi_awregion
   .s_axi_awqos(fsimtop_s_0_axi_awqos),        // input wire [3 : 0] s_axi_awqos
   .s_axi_awvalid(fsimtop_s_0_axi_awvalid),    // input wire s_axi_awvalid
   .s_axi_awready(fsimtop_s_0_axi_awready),    // output wire s_axi_awready

   .s_axi_wdata(fsimtop_s_0_axi_wdata),        // input wire [63 : 0] s_axi_wdata
   .s_axi_wstrb(fsimtop_s_0_axi_wstrb),        // input wire [7 : 0] s_axi_wstrb
   .s_axi_wlast(fsimtop_s_0_axi_wlast),        // input wire s_axi_wlast
   .s_axi_wvalid(fsimtop_s_0_axi_wvalid),      // input wire s_axi_wvalid
   .s_axi_wready(fsimtop_s_0_axi_wready),      // output wire s_axi_wready

   .s_axi_bid(fsimtop_s_0_axi_bid),            // output wire [15 : 0] s_axi_bid
   .s_axi_bresp(fsimtop_s_0_axi_bresp),        // output wire [1 : 0] s_axi_bresp
   .s_axi_bvalid(fsimtop_s_0_axi_bvalid),      // output wire s_axi_bvalid
   .s_axi_bready(fsimtop_s_0_axi_bready),      // input wire s_axi_bready

   .s_axi_arid(fsimtop_s_0_axi_arid),          // input wire [15 : 0] s_axi_arid
   .s_axi_araddr(fsimtop_s_0_axi_araddr),      // input wire [63 : 0] s_axi_araddr
   .s_axi_arlen(fsimtop_s_0_axi_arlen),        // input wire [7 : 0] s_axi_arlen
   .s_axi_arsize(fsimtop_s_0_axi_arsize),      // input wire [2 : 0] s_axi_arsize
   .s_axi_arburst(fsimtop_s_0_axi_arburst),    // input wire [1 : 0] s_axi_arburst
   .s_axi_arlock(fsimtop_s_0_axi_arlock),      // input wire [0 : 0] s_axi_arlock
   // CACHE = xx1x indicates the transcation is modifiable and
   // that the converter should pack narrow reads into wider ones
   .s_axi_arcache(4'h2),                     // input wire [3 : 0] s_axi_arcache
   .s_axi_arprot(fsimtop_s_0_axi_arprot),      // input wire [2 : 0] s_axi_arprot
   .s_axi_arregion(fsimtop_s_0_axi_arregion),  // input wire [3 : 0] s_axi_arregion
   .s_axi_arqos(fsimtop_s_0_axi_arqos),        // input wire [3 : 0] s_axi_arqos
   .s_axi_arvalid(fsimtop_s_0_axi_arvalid),    // input wire s_axi_arvalid
   .s_axi_arready(fsimtop_s_0_axi_arready),    // output wire s_axi_arready

   .s_axi_rid(fsimtop_s_0_axi_rid),            // output wire [15 : 0] s_axi_rid
   .s_axi_rdata(fsimtop_s_0_axi_rdata),        // output wire [63 : 0] s_axi_rdata
   .s_axi_rresp(fsimtop_s_0_axi_rresp),        // output wire [1 : 0] s_axi_rresp
   .s_axi_rlast(fsimtop_s_0_axi_rlast),        // output wire s_axi_rlast
   .s_axi_rvalid(fsimtop_s_0_axi_rvalid),      // output wire s_axi_rvalid
   .s_axi_rready(fsimtop_s_0_axi_rready),      // input wire s_axi_rready

   .m_axi_aclk(clk_main_a0),          // input wire m_axi_aclk
   .m_axi_aresetn(rst_main_n_sync),    // input wire m_axi_aresetn

   .m_axi_awid(clock_converted_axi_0_awid),          // output wire [15 : 0] m_axi_awid
   .m_axi_awaddr(clock_converted_axi_0_awaddr),      // output wire [63 : 0] m_axi_awaddr
   .m_axi_awlen(clock_converted_axi_0_awlen),        // output wire [7 : 0] m_axi_awlen
   .m_axi_awsize(clock_converted_axi_0_awsize),      // output wire [2 : 0] m_axi_awsize
   .m_axi_awburst(clock_converted_axi_0_awburst),    // output wire [1 : 0] m_axi_awburst
   .m_axi_awlock(clock_converted_axi_0_awlock),      // output wire [0 : 0] m_axi_awlock
   .m_axi_awcache(clock_converted_axi_0_awcache),    // output wire [3 : 0] m_axi_awcache
   .m_axi_awprot(clock_converted_axi_0_awprot),      // output wire [2 : 0] m_axi_awprot
   .m_axi_awregion(clock_converted_axi_0_awregion),  // output wire [3 : 0] m_axi_awregion
   .m_axi_awqos(clock_converted_axi_0_awqos),        // output wire [3 : 0] m_axi_awqos
   .m_axi_awvalid(clock_converted_axi_0_awvalid),    // output wire m_axi_awvalid
   .m_axi_awready(clock_converted_axi_0_awready),    // input wire m_axi_awready

   .m_axi_wdata(clock_converted_axi_0_wdata),        // output wire [511 : 0] m_axi_wdata
   .m_axi_wstrb(clock_converted_axi_0_wstrb),        // output wire [63 : 0] m_axi_wstrb
   .m_axi_wlast(clock_converted_axi_0_wlast),        // output wire m_axi_wlast
   .m_axi_wvalid(clock_converted_axi_0_wvalid),      // output wire m_axi_wvalid
   .m_axi_wready(clock_converted_axi_0_wready),      // input wire m_axi_wready

   .m_axi_bid(clock_converted_axi_0_bid),            // input wire [15 : 0] m_axi_bid
   .m_axi_bresp(clock_converted_axi_0_bresp),        // input wire [1 : 0] m_axi_bresp
   .m_axi_bvalid(clock_converted_axi_0_bvalid),      // input wire m_axi_bvalid
   .m_axi_bready(clock_converted_axi_0_bready),      // output wire m_axi_bready

   .m_axi_arid(clock_converted_axi_0_arid),          // output wire [15 : 0] m_axi_arid
   .m_axi_araddr(clock_converted_axi_0_araddr),      // output wire [63 : 0] m_axi_araddr
   .m_axi_arlen(clock_converted_axi_0_arlen),        // output wire [7 : 0] m_axi_arlen
   .m_axi_arsize(clock_converted_axi_0_arsize),      // output wire [2 : 0] m_axi_arsize
   .m_axi_arburst(clock_converted_axi_0_arburst),    // output wire [1 : 0] m_axi_arburst
   .m_axi_arlock(clock_converted_axi_0_arlock),      // output wire [0 : 0] m_axi_arlock
   .m_axi_arcache(clock_converted_axi_0_arcache),    // output wire [3 : 0] m_axi_arcache
   .m_axi_arprot(clock_converted_axi_0_arprot),      // output wire [2 : 0] m_axi_arprot
   .m_axi_arregion(clock_converted_axi_0_arregion),  // output wire [3 : 0] m_axi_arregion
   .m_axi_arqos(clock_converted_axi_0_arqos),        // output wire [3 : 0] m_axi_arqos
   .m_axi_arvalid(clock_converted_axi_0_arvalid),    // output wire m_axi_arvalid
   .m_axi_arready(clock_converted_axi_0_arready),    // input wire m_axi_arready

   .m_axi_rid(clock_converted_axi_0_rid),            // input wire [15 : 0] m_axi_rid
   .m_axi_rdata(clock_converted_axi_0_rdata),        // input wire [511 : 0] m_axi_rdata
   .m_axi_rresp(clock_converted_axi_0_rresp),        // input wire [1 : 0] m_axi_rresp
   .m_axi_rlast(clock_converted_axi_0_rlast),        // input wire m_axi_rlast
   .m_axi_rvalid(clock_converted_axi_0_rvalid),      // input wire m_axi_rvalid
   .m_axi_rready(clock_converted_axi_0_rready)      // output wire m_axi_rready
);

/* steps to move:
 * 1) copy clock converter's M interfaces to dwidth converter's M interfaces: DONE
 * 2) create clock_converted_* signals for clock M to width adapt S: DONE
 * 3) add asserts on arsize and awsize to confirm that they're always b110
*/

// assign cl_sh_ddr_awid = 16'b0; // dwidth convert has no awid for some reason...
// assign cl_sh_ddr_arid = 16'b0; // dwidth convert has no arid for some reason...
// F2: cl_sh_ddr_awid & arid deleted
// unused: sh_cl_ddr_bid
// unused: sh_cl_ddr_rid

axi_dwidth_converter_0 dwidth_adapt_64bits_512bits_0 (
   .s_axi_aclk(clk_main_a0),          // input wire s_axi_aclk
   .s_axi_aresetn(rst_main_n_sync),    // input wire s_axi_aresetn

   .s_axi_awid(clock_converted_axi_0_awid),          // input wire [15 : 0] s_axi_awid
   .s_axi_awaddr(clock_converted_axi_0_awaddr),      // input wire [63 : 0] s_axi_awaddr
   .s_axi_awlen(clock_converted_axi_0_awlen),        // input wire [7 : 0] s_axi_awlen
   .s_axi_awsize(clock_converted_axi_0_awsize),      // input wire [2 : 0] s_axi_awsize
   .s_axi_awburst(clock_converted_axi_0_awburst),    // input wire [1 : 0] s_axi_awburst
   .s_axi_awlock(clock_converted_axi_0_awlock),      // input wire [0 : 0] s_axi_awlock
   .s_axi_awcache(clock_converted_axi_0_awcache),    // input wire [3 : 0] s_axi_awcache
   .s_axi_awprot(clock_converted_axi_0_awprot),      // input wire [2 : 0] s_axi_awprot
   .s_axi_awregion(clock_converted_axi_0_awregion),  // input wire [3 : 0] s_axi_awregion
   .s_axi_awqos(clock_converted_axi_0_awqos),        // input wire [3 : 0] s_axi_awqos
   .s_axi_awvalid(clock_converted_axi_0_awvalid),    // input wire s_axi_awvalid
   .s_axi_awready(clock_converted_axi_0_awready),    // output wire s_axi_awready

   .s_axi_wdata(clock_converted_axi_0_wdata),        // input wire [63 : 0] s_axi_wdata
   .s_axi_wstrb(clock_converted_axi_0_wstrb),        // input wire [7 : 0] s_axi_wstrb
   .s_axi_wlast(clock_converted_axi_0_wlast),        // input wire s_axi_wlast
   .s_axi_wvalid(clock_converted_axi_0_wvalid),      // input wire s_axi_wvalid
   .s_axi_wready(clock_converted_axi_0_wready),      // output wire s_axi_wready

   .s_axi_bid(clock_converted_axi_0_bid),            // output wire [15 : 0] s_axi_bid
   .s_axi_bresp(clock_converted_axi_0_bresp),        // output wire [1 : 0] s_axi_bresp
   .s_axi_bvalid(clock_converted_axi_0_bvalid),      // output wire s_axi_bvalid
   .s_axi_bready(clock_converted_axi_0_bready),      // input wire s_axi_bready

   .s_axi_arid(clock_converted_axi_0_arid),          // input wire [15 : 0] s_axi_arid
   .s_axi_araddr(clock_converted_axi_0_araddr),      // input wire [63 : 0] s_axi_araddr
   .s_axi_arlen(clock_converted_axi_0_arlen),        // input wire [7 : 0] s_axi_arlen
   .s_axi_arsize(clock_converted_axi_0_arsize),      // input wire [2 : 0] s_axi_arsize
   .s_axi_arburst(clock_converted_axi_0_arburst),    // input wire [1 : 0] s_axi_arburst
   .s_axi_arlock(clock_converted_axi_0_arlock),      // input wire [0 : 0] s_axi_arlock
   .s_axi_arcache(clock_converted_axi_0_arcache),    // input wire [3 : 0] s_axi_arcache
   .s_axi_arprot(clock_converted_axi_0_arprot),      // input wire [2 : 0] s_axi_arprot
   .s_axi_arregion(clock_converted_axi_0_arregion),  // input wire [3 : 0] s_axi_arregion
   .s_axi_arqos(clock_converted_axi_0_arqos),        // input wire [3 : 0] s_axi_arqos
   .s_axi_arvalid(clock_converted_axi_0_arvalid),    // input wire s_axi_arvalid
   .s_axi_arready(clock_converted_axi_0_arready),    // output wire s_axi_arready

   .s_axi_rid(clock_converted_axi_0_rid),            // output wire [15 : 0] s_axi_rid
   .s_axi_rdata(clock_converted_axi_0_rdata),        // output wire [63 : 0] s_axi_rdata
   .s_axi_rresp(clock_converted_axi_0_rresp),        // output wire [1 : 0] s_axi_rresp
   .s_axi_rlast(clock_converted_axi_0_rlast),        // output wire s_axi_rlast
   .s_axi_rvalid(clock_converted_axi_0_rvalid),      // output wire s_axi_rvalid
   .s_axi_rready(clock_converted_axi_0_rready),      // input wire s_axi_rready


   .m_axi_awaddr(cl_sh_ddr_awaddr),      // output wire [63 : 0] m_axi_awaddr
   .m_axi_awlen(cl_sh_ddr_awlen),        // output wire [7 : 0] m_axi_awlen
   .m_axi_awsize(cl_sh_ddr_awsize),      // output wire [2 : 0] m_axi_awsize
   .m_axi_awburst(cl_sh_ddr_awburst),    // output wire [1 : 0] m_axi_awburst
   .m_axi_awlock(),      // output wire [0 : 0] m_axi_awlock
   .m_axi_awcache(),    // output wire [3 : 0] m_axi_awcache
   .m_axi_awprot(),      // output wire [2 : 0] m_axi_awprot
   .m_axi_awregion(),  // output wire [3 : 0] m_axi_awregion
   .m_axi_awqos(),        // output wire [3 : 0] m_axi_awqos
   .m_axi_awvalid(cl_sh_ddr_awvalid),    // output wire m_axi_awvalid
   .m_axi_awready(sh_cl_ddr_awready),    // input wire m_axi_awready

   .m_axi_wdata(cl_sh_ddr_wdata),        // output wire [511 : 0] m_axi_wdata
   .m_axi_wstrb(cl_sh_ddr_wstrb),        // output wire [63 : 0] m_axi_wstrb
   .m_axi_wlast(cl_sh_ddr_wlast),        // output wire m_axi_wlast
   .m_axi_wvalid(cl_sh_ddr_wvalid),      // output wire m_axi_wvalid
   .m_axi_wready(sh_cl_ddr_wready),      // input wire m_axi_wready

   .m_axi_bresp(sh_cl_ddr_bresp),        // input wire [1 : 0] m_axi_bresp
   .m_axi_bvalid(sh_cl_ddr_bvalid),      // input wire m_axi_bvalid
   .m_axi_bready(cl_sh_ddr_bready),      // output wire m_axi_bready

   .m_axi_araddr(cl_sh_ddr_araddr),      // output wire [63 : 0] m_axi_araddr
   .m_axi_arlen(cl_sh_ddr_arlen),        // output wire [7 : 0] m_axi_arlen
   .m_axi_arsize(cl_sh_ddr_arsize),      // output wire [2 : 0] m_axi_arsize
   .m_axi_arburst(cl_sh_ddr_arburst),    // output wire [1 : 0] m_axi_arburst
   .m_axi_arlock(),      // output wire [0 : 0] m_axi_arlock
   .m_axi_arcache(),    // output wire [3 : 0] m_axi_arcache
   .m_axi_arprot(),      // output wire [2 : 0] m_axi_arprot
   .m_axi_arregion(),  // output wire [3 : 0] m_axi_arregion
   .m_axi_arqos(),        // output wire [3 : 0] m_axi_arqos
   .m_axi_arvalid(cl_sh_ddr_arvalid),    // output wire m_axi_arvalid
   .m_axi_arready(sh_cl_ddr_arready),    // input wire m_axi_arready

   .m_axi_rdata(sh_cl_ddr_rdata),        // input wire [511 : 0] m_axi_rdata
   .m_axi_rresp(sh_cl_ddr_rresp),        // input wire [1 : 0] m_axi_rresp
   .m_axi_rlast(sh_cl_ddr_rlast),        // input wire m_axi_rlast
   .m_axi_rvalid(sh_cl_ddr_rvalid),      // input wire m_axi_rvalid
   .m_axi_rready(cl_sh_ddr_rready)      // output wire m_axi_rready
);


// Tie-off F1Shim io_slave_1 AXI port (DDR Channel A equivalent)
assign fsimtop_s_1_axi_awready = 1'b0;
assign fsimtop_s_1_axi_wready = 1'b0;
assign fsimtop_s_1_axi_arready = 1'b0;

assign fsimtop_s_1_axi_bid = 16'b0;
assign fsimtop_s_1_axi_bresp = 2'b0;
assign fsimtop_s_1_axi_bvalid = 1'b0;

assign fsimtop_s_1_axi_rid = 16'b0;
assign fsimtop_s_1_axi_rdata = 64'b0;
assign fsimtop_s_1_axi_rresp = 2'b0;
assign fsimtop_s_1_axi_rlast = 1'b0;
assign fsimtop_s_1_axi_rvalid = 1'b0;

// Tie-off F1Shim io_slave_2 AXI port (DDR Channel B equivalent)
assign fsimtop_s_2_axi_awready = 1'b0;
assign fsimtop_s_2_axi_wready = 1'b0;
assign fsimtop_s_2_axi_arready = 1'b0;

assign fsimtop_s_2_axi_bid = 16'b0;
assign fsimtop_s_2_axi_bresp = 2'b0;
assign fsimtop_s_2_axi_bvalid = 1'b0;

assign fsimtop_s_2_axi_rid = 16'b0;
assign fsimtop_s_2_axi_rdata = 64'b0;
assign fsimtop_s_2_axi_rresp = 2'b0;
assign fsimtop_s_2_axi_rlast = 1'b0;
assign fsimtop_s_2_axi_rvalid = 1'b0;

// Tie-off F1Shim io_slave_3 AXI port (DDR Channel D equivalent)
assign fsimtop_s_3_axi_awready = 1'b0;
assign fsimtop_s_3_axi_wready = 1'b0;
assign fsimtop_s_3_axi_arready = 1'b0;

assign fsimtop_s_3_axi_bid = 16'b0;
assign fsimtop_s_3_axi_bresp = 2'b0;
assign fsimtop_s_3_axi_bvalid = 1'b0;

assign fsimtop_s_3_axi_rid = 16'b0;
assign fsimtop_s_3_axi_rdata = 64'b0;
assign fsimtop_s_3_axi_rresp = 2'b0;
assign fsimtop_s_3_axi_rlast = 1'b0;
assign fsimtop_s_3_axi_rvalid = 1'b0;

//-------------------------------------------
// Tie-Off Unused Global Signals
//-------------------------------------------
// The functionality for these signals is TBD so they can can be tied-off.
assign clk_hbm_ref = 1'b0;
assign cl_sh_status0[31:0] = 32'h0;
assign cl_sh_status1[31:0] = 32'h0;
assign cl_sh_status2[31:0] = 32'h0; // new in f2
assign cl_sh_status_vled[15:0] = 16'h0; // virtual leds


//-----------------------------------------------
// Debug bridge, used if need Virtual JTAG
//-----------------------------------------------
`ifndef DISABLE_VJTAG_DEBUG

// Flop for timing global clock counter
logic[63:0] sh_cl_glcount0_q;

always_ff @(posedge clk_main_a0)
   if (!rst_main_n_sync)
      sh_cl_glcount0_q <= 0;
   else
      sh_cl_glcount0_q <= sh_cl_glcount0;


logic zeroila;
assign zeroila = 64'b0;

// Integrated Logic Analyzers (ILA)
// rh: ILA coming soon! or it breaks.
// ila_0 CL_ILA_0 (
//                   .clk    (clk_main_a0),
//                   .probe0 (zeroila),
//                   .probe1 (zeroila),
//                   .probe2 (zeroila),
//                   .probe3 (zeroila),
//                   .probe4 (zeroila),
//                   .probe5 (zeroila)
//                   );

// ila_0 CL_ILA_1 (
//                   .clk    (clk_main_a0),
//                   .probe0 (zeroila),
//                   .probe1 (zeroila),
//                   .probe2 (zeroila),
//                   .probe3 (zeroila),
//                   .probe4 (zeroila),
//                   .probe5 (zeroila)
//                   );

// // Debug Bridge 
// cl_debug_bridge CL_DEBUG_BRIDGE (
//    .clk(clk_main_a0),
//    .S_BSCAN_drck(drck),
//    .S_BSCAN_shift(shift),
//    .S_BSCAN_tdi(tdi),
//    .S_BSCAN_update(update),
//    .S_BSCAN_sel(sel),
//    .S_BSCAN_tdo(tdo),
//    .S_BSCAN_tms(tms),
//    .S_BSCAN_tck(tck),
//    .S_BSCAN_runtest(runtest),
//    .S_BSCAN_reset(reset),
//    .S_BSCAN_capture(capture),
//    .S_BSCAN_bscanid_en(bscanid_en)
// );

// //-----------------------------------------------
// // VIO Example - Needs Virtual JTAG
// //-----------------------------------------------
// // Counter running at 125MHz

// logic      vo_cnt_enable;
// logic      vo_cnt_load;
// logic      vo_cnt_clear;
// logic      vo_cnt_oneshot;
// logic [7:0]  vo_tick_value;
// logic [15:0] vo_cnt_load_value;
// logic [15:0] vo_cnt_watermark;

// logic      vo_cnt_enable_q = 0;
// logic      vo_cnt_load_q = 0;
// logic      vo_cnt_clear_q = 0;
// logic      vo_cnt_oneshot_q = 0;
// logic [7:0]  vo_tick_value_q = 0;
// logic [15:0] vo_cnt_load_value_q = 0;
// logic [15:0] vo_cnt_watermark_q = 0;

// logic        vi_tick;
// logic        vi_cnt_ge_watermark;
// logic [7:0]  vi_tick_cnt = 0;
// logic [15:0] vi_cnt = 0;

// // Tick counter and main counter
// always @(posedge clk_main_a0) begin

//    vo_cnt_enable_q     <= vo_cnt_enable    ;
//    vo_cnt_load_q       <= vo_cnt_load      ;
//    vo_cnt_clear_q      <= vo_cnt_clear     ;
//    vo_cnt_oneshot_q    <= vo_cnt_oneshot   ;
//    vo_tick_value_q     <= vo_tick_value    ;
//    vo_cnt_load_value_q <= vo_cnt_load_value;
//    vo_cnt_watermark_q  <= vo_cnt_watermark ;

//    vi_tick_cnt = vo_cnt_clear_q ? 0 :
//                   ~vo_cnt_enable_q ? vi_tick_cnt :
//                   (vi_tick_cnt >= vo_tick_value_q) ? 0 :
//                   vi_tick_cnt + 1;

//    vi_cnt = vo_cnt_clear_q ? 0 :
//             vo_cnt_load_q ? vo_cnt_load_value_q :
//             ~vo_cnt_enable_q ? vi_cnt :
//             (vi_tick_cnt >= vo_tick_value_q) && (~vo_cnt_oneshot_q || (vi_cnt <= 16'hFFFF)) ? vi_cnt + 1 :
//             vi_cnt;

//    vi_tick = (vi_tick_cnt >= vo_tick_value_q);

//    vi_cnt_ge_watermark = (vi_cnt >= vo_cnt_watermark_q);
   
// end // always @ (posedge clk_main_a0)


// vio_0 CL_VIO_0 (
//                   .clk    (clk_main_a0),
//                   .probe_in0  (vi_tick),
//                   .probe_in1  (vi_cnt_ge_watermark),
//                   .probe_in2  (vi_tick_cnt),
//                   .probe_in3  (vi_cnt),
//                   .probe_out0 (vo_cnt_enable),
//                   .probe_out1 (vo_cnt_load),
//                   .probe_out2 (vo_cnt_clear),
//                   .probe_out3 (vo_cnt_oneshot),
//                   .probe_out4 (vo_tick_value),
//                   .probe_out5 (vo_cnt_load_value),
//                   .probe_out6 (vo_cnt_watermark)
//                   );

// ila_vio_counter CL_VIO_ILA (
//                   .clk     (clk_main_a0),
//                   .probe0  (vi_tick),
//                   .probe1  (vi_cnt_ge_watermark),
//                   .probe2  (vi_tick_cnt),
//                   .probe3  (vi_cnt),
//                   .probe4  (vo_cnt_enable_q),
//                   .probe5  (vo_cnt_load_q),
//                   .probe6  (vo_cnt_clear_q),
//                   .probe7  (vo_cnt_oneshot_q),
//                   .probe8  (vo_tick_value_q),
//                   .probe9  (vo_cnt_load_value_q),
//                   .probe10 (vo_cnt_watermark_q)
//                   );

`endif //  `ifndef DISABLE_VJTAG_DEBUG

endmodule
