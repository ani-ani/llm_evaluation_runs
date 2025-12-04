module power_list (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] nums [0:7],
  output reg [31:0] results [0:7],
  output reg done
);

  typedef enum logic [1:0] {IDLE, COMPUTE, DONE} state_t;
  state_t state;

  reg [3:0] captured_n;
  reg [15:0] captured_nums [0:7];
  reg [3:0] counter;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      for (int i=0; i<8; i++) results[i] <= '0;
      captured_n <= '0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            captured_n <= n;
            for (int i=0; i<8; i++) captured_nums[i] <= nums[i];
            if (n == 0) begin
              for (int i=0; i<8; i++) results[i] <= 32'd1;
              state <= DONE;
            end else begin
              for (int i=0; i<8; i++) results[i] <= nums[i];
              if (n == 1) begin
                state <= DONE;
              end else begin
                counter <= 0;
                state <= COMPUTE;
              end
            end
          end
        end

        COMPUTE: begin
          if (counter < (captured_n - 1)) begin
            for (int i=0; i<8; i++) results[i] <= results[i] * captured_nums[i];
            counter <= counter + 1;
            state <= COMPUTE;
          end else begin
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule