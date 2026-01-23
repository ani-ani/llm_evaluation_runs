module snake_to_camel (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  output reg ready,
  output reg [7:0] char_out,
  output reg valid_out,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state, next_state;
  reg [7:0] prev_char;
  reg capitalize_next;
  reg [3:0] output_count;
  reg [3:0] idle_cycles;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      prev_char <= 8'h00;
      capitalize_next <= 1'b0;
      output_count <= 4'd0;
      idle_cycles <= 4'd0;
      ready <= 1'b0;
      char_out <= 8'h00;
      valid_out <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      if (state == PROCESSING && valid_in && ready) begin
        prev_char <= char_in;
        if (char_in == 8'h5F) begin
          capitalize_next <= 1'b1;
        end else begin
          capitalize_next <= 1'b0;
        end
      end
    end
  end

  always @(*) begin
    next_state = state;
    ready = 1'b0;
    char_out = 8'h00;
    valid_out = 1'b0;
    done = 1'b0;

    case (state)
      IDLE: begin
        ready = 1'b1;
        if (start) begin
          next_state = PROCESSING;
          capitalize_next = 1'b1;
          output_count = 4'd0;
        end
      end

      PROCESSING: begin
        if (valid_in && (char_in != 8'h5F)) begin
          ready = 1'b1;
          if (capitalize_next && (char_in >= 8'h61) && (char_in <= 8'h7A)) begin
            char_out = char_in - 8'h20;
          end else begin
            char_out = char_in;
          end
          valid_out = 1'b1;
          output_count = output_count + 1;
        end else if (char_in == 8'h5F) begin
          ready = 1'b1;
        end else begin
          ready = 1'b0;
          if (idle_cycles == 4'd1) begin
            idle_cycles = idle_cycles + 1;
          end else if (idle_cycles == 4'd2) begin
            next_state = DONE;
            done = 1'b1;
          end else begin
            idle_cycles = idle_cycles + 1;
          end
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 1'b0;
        end
      end
    endcase
  end

endmodule