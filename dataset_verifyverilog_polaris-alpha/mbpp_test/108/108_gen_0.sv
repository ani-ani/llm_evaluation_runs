module sorted_list_merger(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] list1 [0:7],
  input  [7:0] list2 [0:7],
  input  [7:0] list3 [0:7],
  output reg [7:0] merged [0:23],
  output reg       done
);

  // Internal pointers and cycle counter
  reg [3:0] p1;
  reg [3:0] p2;
  reg [3:0] p3;
  reg [4:0] out_pos;
  reg       active;

  // Current values from lists based on pointers
  wire [7:0] v1 = (p1 < 8) ? list1[p1] : 8'hFF;
  wire [7:0] v2 = (p2 < 8) ? list2[p2] : 8'hFF;
  wire [7:0] v3 = (p3 < 8) ? list3[p3] : 8'hFF;

  // Depletion conditions
  wire d1 = (p1 >= 8) || (v1 == 8'hFF);
  wire d2 = (p2 >= 8) || (v2 == 8'hFF);
  wire d3 = (p3 >= 8) || (v3 == 8'hFF);

  // Next pointer increments
  reg inc1, inc2, inc3;

  // Combinational selection of minimum valid value
  reg [7:0] sel_val;

  always @* begin
    // Default increments
    inc1 = 1'b0;
    inc2 = 1'b0;
    inc3 = 1'b0;
    sel_val = 8'hFF;

    // Determine smallest among non-depleted lists (with deterministic tie-breaking)
    if (!d1 && (v1 <= v2 || d2) && (v1 <= v3 || d3)) begin
      sel_val = v1;
      inc1 = 1'b1;
    end else if (!d2 && (v2 <= v1 || d1) && (v2 <= v3 || d3)) begin
      sel_val = v2;
      inc2 = 1'b1;
    end else if (!d3 && (v3 <= v1 || d1) && (v3 <= v2 || d2)) begin
      sel_val = v3;
      inc3 = 1'b1;
    end else begin
      // If all depleted, sel_val remains 8'hFF (padding)
      sel_val = 8'hFF;
    end
  end

  // Sequential control and output generation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p1      <= 4'd0;
      p2      <= 4'd0;
      p3      <= 4'd0;
      out_pos <= 5'd0;
      done    <= 1'b0;
      active  <= 1'b0;
    end else begin
      // Start condition: latch start edge (level-sensitive while idle)
      if (start && !active) begin
        p1      <= 4'd0;
        p2      <= 4'd0;
        p3      <= 4'd0;
        out_pos <= 5'd0;
        done    <= 1'b0;
        active  <= 1'b1;
      end else if (active) begin
        // Perform one merge step per cycle
        merged[out_pos] <= sel_val;

        // Advance pointers based on selected source
        if (inc1) p1 <= p1 + 1'b1;
        if (inc2) p2 <= p2 + 1'b1;
        if (inc3) p3 <= p3 + 1'b1;

        // Update position / done
        if (out_pos == 5'd23) begin
          done   <= 1'b1;
          active <= 1'b0;
        end else begin
          out_pos <= out_pos + 1'b1;
        end
      end else begin
        // Idle state: hold done until next start or reset
        done <= done;
      end
    end
  end

endmodule