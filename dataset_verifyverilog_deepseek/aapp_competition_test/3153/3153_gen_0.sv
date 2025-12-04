module purchase_outcome_decoder (
  input clk,
  input rst_n,
  input start,
  input [3:0][15:0] child_count,
  input [2:0] purchase_count,
  input [5:0][1:0][1:0] purchase_pairs,
  output reg [5:0][1:0] outcome,
  output reg done
);

  reg [2:0] purchase_step;
  reg [3:0][15:0] current_counts;
  reg processing;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      outcome <= '{default:0};
      done <= 0;
      processing <= 0;
      purchase_step <= 0;
      current_counts <= '{default:0};
    end else begin
      if (processing) begin
        if (purchase_step < purchase_count) begin
          logic [1:0] a = purchase_pairs[purchase_step][0];
          logic [1:0] b = purchase_pairs[purchase_step][1];
          logic [15:0] required_a = child_count[a] - current_counts[a];
          logic [15:0] required_b = child_count[b] - current_counts[b];
          logic [1:0] outcome_val;

          if (required_a > required_b || (required_a == required_b && a < b)) begin
            outcome_val = 2'b10;
          end else if (required_b > required_a) begin
            outcome_val = 2'b00;
          end else begin
            outcome_val = 2'b01;
          end

          outcome[purchase_step] <= outcome_val;

          case (outcome_val)
            2'b10: current_counts[a] <= current_counts[a] + 16'd1;
            2'b00: current_counts[b] <= current_counts[b] + 16'd1;
            2'b01: begin
              current_counts[a] <= current_counts[a] + 16'd1;
              current_counts[b] <= current_counts[b] + 16'd1;
            end
          endcase

          purchase_step <= purchase_step + 1;
        end else begin
          processing <= 0;
          done <= 1;
        end
      end else begin
        done <= 0;
        if (start) begin
          processing <= 1;
          purchase_step <= 0;
          current_counts <= '{default:0};
          outcome <= '{default:0};
        end
      end
    end
  end

endmodule