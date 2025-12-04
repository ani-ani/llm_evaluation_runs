module median_calculator (
  input clk,
  input rst_n,
  input [3:0] n,
  input [7:0][15:0] data,
  input start_trig,
  output reg [15:0] result,
  output reg done
);

  reg signed [15:0] data_reg [0:7];
  reg signed [15:0] sorted_data [0:7];
  reg signed [15:0] next_sorted_data [0:7];
  reg [3:0] n_reg;
  reg [3:0] cycle_count;
  reg processing;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      processing <= 1'b0;
      cycle_count <= 4'd0;
      result <= 16'sd0;
      for (int i=0; i<8; i=i+1) begin
        data_reg[i] <= 16'sd0;
        sorted_data[i] <= 16'sd0;
      end
    end else begin
      if (start_trig && !processing) begin
        done <= 1'b0;
        processing <= 1'b1;
        cycle_count <= 4'd0;
        n_reg <= n;
        for (int i=0; i<8; i=i+1) begin
          data_reg[i] <= data[i];
          sorted_data[i] <= data[i];
        end
      end else if (processing) begin
        sorted_data <= next_sorted_data;
        cycle_count <= cycle_count + 1;
        
        if (cycle_count == 4'd6) begin
          if (n_reg[0]) begin
            result <= sorted_data[(n_reg-1)>>1];
          end else begin
            reg signed [16:0] temp_sum;
            temp_sum = sorted_data[(n_reg>>1)-1] + sorted_data[n_reg>>1] + 1;
            result <= temp_sum[16:1];
          end
        end else if (cycle_count == 4'd7) begin
          done <= 1'b1;
          processing <= 1'b0;
        end
      end else begin
        done <= 1'b0;
      end
    end
  end

  always_comb begin
    for (int i=0; i<8; i=i+1) begin
      next_sorted_data[i] = sorted_data[i];
    end
    
    if (processing) begin
      case (cycle_count)
        4'd0: begin
          if (0 < n_reg && 1 < n_reg && sorted_data[0] > sorted_data[1]) begin
            next_sorted_data[0] = sorted_data[1];
            next_sorted_data[1] = sorted_data[0];
          end
          if (2 < n_reg && 3 < n_reg && sorted_data[2] > sorted_data[3]) begin
            next_sorted_data[2] = sorted_data[3];
            next_sorted_data[3] = sorted_data[2];
          end
          if (4 < n_reg && 5 < n_reg && sorted_data[4] > sorted_data[5]) begin
            next_sorted_data[4] = sorted_data[5];
            next_sorted_data[5] = sorted_data[4];
          end
          if (6 < n_reg && 7 < n_reg && sorted_data[6] > sorted_data[7]) begin
            next_sorted_data[6] = sorted_data[7];
            next_sorted_data[7] = sorted_data[6];
          end
        end
        4'd1: begin
          if (0 < n_reg && 2 < n_reg && sorted_data[0] > sorted_data[2]) begin
            next_sorted_data[0] = sorted_data[2];
            next_sorted_data[2] = sorted_data[0];
          end
          if (1 < n_reg && 3 < n_reg && sorted_data[1] > sorted_data[3]) begin
            next_sorted_data[1] = sorted_data[3];
            next_sorted_data[3] = sorted_data[1];
          end
          if (4 < n_reg && 6 < n_reg && sorted_data[4] > sorted_data[6]) begin
            next_sorted_data[4] = sorted_data[6];
            next_sorted_data[6] = sorted_data[4];
          end
          if (5 < n_reg && 7 < n_reg && sorted_data[5] > sorted_data[7]) begin
            next_sorted_data[5] = sorted_data[7];
            next_sorted_data[7] = sorted_data[5];
          end
        end
        4'd2: begin
          if (0 < n_reg && 4 < n_reg && sorted_data[0] > sorted_data[4]) begin
            next_sorted_data[0] = sorted_data[4];
            next_sorted_data[4] = sorted_data[0];
          end
          if (1 < n_reg && 5 < n_reg && sorted_data[1] > sorted_data[5]) begin
            next_sorted_data[1] = sorted_data[5];
            next_sorted_data[5] = sorted_data[1];
          end
          if (2 < n_reg && 6 < n_reg && sorted_data[2] > sorted_data[6]) begin
            next_sorted_data[2] = sorted_data[6];
            next_sorted_data[6] = sorted_data[2];
          end
          if (3 < n_reg && 7 < n_reg && sorted_data[3] > sorted_data[7]) begin
            next_sorted_data[3] = sorted_data[7];
            next_sorted_data[7] = sorted_data[3];
          end
        end
        4'd3: begin
          if (1 < n_reg && 2 < n_reg && sorted_data[1] > sorted_data[2]) begin
            next_sorted_data[1] = sorted_data[2];
            next_sorted_data[2] = sorted_data[1];
          end
          if (3 < n_reg && 4 < n_reg && sorted_data[3] > sorted_data[4]) begin
            next_sorted_data[3] = sorted_data[4];
            next_sorted_data[4] = sorted_data[3];
          end
          if (5 < n_reg && 6 < n_reg && sorted_data[5] > sorted_data[6]) begin
            next_sorted_data[5] = sorted_data[6];
            next_sorted_data[6] = sorted_data[5];
          end
        end
        4'd4: begin
          if (2 < n_reg && 4 < n_reg && sorted_data[2] > sorted_data[4]) begin
            next_sorted_data[2] = sorted_data[4];
            next_sorted_data[4] = sorted_data[2];
          end
          if (3 < n_reg && 5 < n_reg && sorted_data[3] > sorted_data[5]) begin
            next_sorted_data[3] = sorted_data[5];
            next_sorted_data[5] = sorted_data[3];
          end
        end
        4'd5: begin
          if (1 < n_reg && 2 < n_reg && sorted_data[1] > sorted_data[2]) begin
            next_sorted_data[1] = sorted_data[2];
            next_sorted_data[2] = sorted_data[1];
          end
          if (3 < n_reg && 4 < n_reg && sorted_data[3] > sorted_data[4]) begin
            next_sorted_data[3] = sorted_data[4];
            next_sorted_data[4] = sorted_data[3];
          end
          if (5 < n_reg && 6 < n_reg && sorted_data[5] > sorted_data[6]) begin
            next_sorted_data[5] = sorted_data[6];
            next_sorted_data[6] = sorted_data[5];
          end
        end
        default: begin
          for (int i=0; i<8; i=i+1) begin
            next_sorted_data[i] = sorted_data[i];
          end
        end
      endcase
    end
  end

endmodule