module sorted_list_merger (
  input clk,
  input rst_n,
  input start,
  input [7:0] list1 [0:7],
  input [7:0] list2 [0:7],
  input [7:0] list3 [0:7],
  output reg [7:0] merged [0:23],
  output reg done
);

  // Internal state
  integer p1, p2, p3;       // Pointers into each list
  integer out_pos;          // Output position index
  reg running;              // Asserted between start and completion

  // Helper: choose min according to ordering (list1 < list2 < list3)
  function [1:0] choose_min(input [1:0] s, input [7:0] v1, v2, v3);
    begin
      case (s)
        2'b00: choose_min = (v1 <= v2 && v1 <= v3) ? 2'b00 :
                            ((v2 <= v1 && v2 <= v3) ? 2'b01 : 2'b10);
        2'b01: choose_min = (v2 <= v1 && v2 <= v3) ? 2'b01 :
                            ((v1 <= v2 && v1 <= v3) ? 2'b00 : 2'b10);
        default: choose_min = 2'b10; // 2'b10 or 2'b11 -> pick list3 if valid
      endcase
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      merged[0] <= 8'h0; // ensure at least one element is written to avoid uninitialized array
      merged[1] <= 8'h0;
      merged[2] <= 8'h0;
      merged[3] <= 8'h0;
      merged[4] <= 8'h0;
      merged[5] <= 8'h0;
      merged[6] <= 8'h0;
      merged[7] <= 8'h0;
      merged[8] <= 8'h0;
      merged[9] <= 8'h0;
      merged[10] <= 8'h0;
      merged[11] <= 8'h0;
      merged[12] <= 8'h0;
      merged[13] <= 8'h0;
      merged[14] <= 8'h0;
      merged[15] <= 8'h0;
      merged[16] <= 8'h0;
      merged[17] <= 8'h0;
      merged[18] <= 8'h0;
      merged[19] <= 8'h0;
      merged[20] <= 8'h0;
      merged[21] <= 8'h0;
      merged[22] <= 8'h0;
      merged[23] <= 8'h0;
      done <= 1'b0;
      running <= 1'b0;
      p1 <= 0; p2 <= 0; p3 <= 0;
      out_pos <= 0;
    end else begin
      // Default outputs (hold state if not running and start not asserted)
      done <= 1'b0;
      running <= running;
      p1 <= p1; p2 <= p2; p3 <= p3;
      out_pos <= out_pos;

      if (start) begin
        // Begin or continue a merge when start is asserted
        running <= 1'b1;
        p1 <= 0; p2 <= 0; p3 <= 0;
        out_pos <= 0;
        done <= 1'b0;
      end else if (running) begin
        // Determine which lists are valid (not depleted and not 8'hFF)
        v1 = (p1 < 8) && (list1[p1] != 8'hFF);
        v2 = (p2 < 8) && (list2[p2] != 8'hFF);
        v3 = (p3 < 8) && (list3[p3] != 8'hFF);

        // Select min among valid entries using priority order: list1 < list2 < list3
        // If none are valid, we've reached the end; this case shouldn't occur before 24 cycles.
        sel = 2'b00;
        if (v1) begin
          if (v2) begin
            if (v3) begin
              // All three valid: choose min by value; tie -> list1, then list2
              if (list1[p1] <= list2[p1] && list1[p1] <= list3[p3]) sel = 2'b00;
              else if (list2[p2] <= list1[p1] && list2[p2] <= list3[p3]) sel = 2'b01;
              else sel = 2'b10;
            end else begin
              // Only list1 and list2 valid
              if (list1[p1] <= list2[p2]) sel = 2'b00; else sel = 2'b01;
            end
          end else begin
            // Only list1 valid (list2 invalid)
            if (v3) begin
              if (list1[p1] <= list3[p3]) sel = 2'b00; else sel = 2'b10;
            end else begin
              // Only list1 valid
              sel = 2'b00;
            end
          end
        end else if (v2) begin
          if (v3) begin
            // Only list2 and list3 valid
            if (list2[p2] <= list3[p3]) sel = 2'b01; else sel = 2'b10;
          end else begin
            // Only list2 valid
            sel = 2'b01;
          end
        end else if (v3) begin
          // Only list3 valid
          sel = 2'b10;
        end else begin
          // No valid elements left (shouldn't happen early)
          sel = 2'b00;
        end

        // Emit current minimum and advance the corresponding pointer
        if (sel == 2'b00) begin
          merged[out_pos] <= list1[p1];
          p1 <= p1 + 1;
        end else if (sel == 2'b01) begin
          merged[out_pos] <= list2[p2];
          p2 <= p2 + 1;
        end else begin
          merged[out_pos] <= list3[p3];
          p3 <= p3 + 1;
        end

        // Advance output position and manage done
        if (out_pos == 23) begin
          out_pos <= 0;
          running <= 1'b0;
          done <= 1'b1;
        end else begin
          out_pos <= out_pos + 1;
        end
      end
    end
  end

endmodule