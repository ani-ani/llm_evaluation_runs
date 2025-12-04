module color_code_verifier(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] p,
  input [15:0] palette,
  input [15:0][3:0] sequence_in,
  output reg valid,
  output reg done
);

  typedef enum logic [1:0] { IDLE, PROCESSING, DONE } state_t;
  state_t state;
  reg [3:0] counter;
  reg [15:0] elements_count_reg;
  reg [15:0] max_index_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 4'd0;
      valid <= 1'b0;
      done <= 1'b0;
      elements_count_reg <= 16'd0;
      max_index_reg <= 16'd0;
    end else begin
      done <= 1'b0;
      case (state)
        IDLE: begin
          if (start) begin
            elements_count_reg <= 16'd1 << n;
            max_index_reg <= (16'd1 << n) - 16'd2;
            if ((16'd1 << n) <= 16'd1) begin
              state <= DONE;
              valid <= 1'b1;
              done <= 1'b1;
            end else begin
              state <= PROCESSING;
              counter <= 4'd0;
              valid <= 1'b0;
            end
          end
        end

        PROCESSING: begin
          automatic logic [3:0] current_element = sequence_in[counter];
          automatic logic [3:0] next_element = sequence_in[counter + 1];
          automatic logic [3:0] diff = current_element ^ next_element;
          automatic logic [3:0] distance = diff[0] + diff[1] + diff[2] + diff[3];
          automatic logic invalid_trans;

          invalid_trans = (distance < 1) || (distance > p) || !palette[distance-1];

          if (invalid_trans) begin
            state <= DONE;
            valid <= 1'b0;
            done <= 1'b1;
          end else if (counter == max_index_reg) begin
            state <= DONE;
            valid <= 1'b1;
            done <= 1'b1;
          end else begin
            counter <= counter + 1;
          end
        end

        DONE: begin
          if (start) begin
            elements_count_reg <= 16'd1 << n;
            max_index_reg <= (16'd1 << n) - 16'd2;
            if ((16'd1 << n) <= 16'd1) begin
              valid <= 1'b1;
              done <= 1'b1;
            end else begin
              state <= PROCESSING;
              counter <= 4'd0;
              valid <= 1'b0;
              done <= 1'b0;
            end
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule