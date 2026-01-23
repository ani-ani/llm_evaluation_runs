module right_insertion (
  input clk,
  input rst_n,
  input start,
  input [3:0] value,
  input [7:0] sorted_data [7:0],
  output reg [3:0] position,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SEARCHING,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [3:0] left = 0;
  reg [3:0] right = 8;
  reg [3:0] mid;
  reg [3:0] counter = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      left <= 0;
      right <= 8;
      counter <= 0;
      position <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SEARCHING;
            left <= 0;
            right <= 8;
            counter <= 0;
            done <= 0;
          end
        end
        SEARCHING: begin
          if (counter < 10) begin
            if (left < right) begin
              mid <= (left + right) >> 1;
              if (sorted_data[mid] <= value) begin
                left <= mid + 1;
              end else begin
                right <= mid;
              end
            end else begin
              position <= left;
              state <= DONE;
            end
            counter <= counter + 1;
          end else begin
            position <= left;
            state <= DONE;
          end
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule