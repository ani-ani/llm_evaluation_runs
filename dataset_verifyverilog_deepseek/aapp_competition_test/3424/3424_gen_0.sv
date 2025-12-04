module age_base_finder(
  input clk,
  input rst_n,
  input start,
  input [15:0] y,
  input [15:0] l,
  output reg [15:0] b,
  output reg done
);

typedef enum logic [2:0] {
  IDLE,
  INIT,
  CHECK_BASE,
  DECOMPOSE,
  CHECK_VALID
} state_t;

reg [15:0] current_base;
reg [15:0] temp_y;
reg [54:0] formed_number;
reg [4:0] digit_count;
reg digit_valid;
state_t state;

wire [15:0] next_temp_y = temp_y / current_base;
wire [15:0] digit = temp_y % current_base;
wire [54:0] l_ext = {39'b0, l};

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    b <= 16'b0;
    done <= 1'b0;
    current_base <= 16'b0;
    temp_y <= 16'b0;
    formed_number <= 55'b0;
    digit_count <= 5'b0;
    digit_valid <= 1'b0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        b <= 16'b0;
        if (start) state <= INIT;
      end
      
      INIT: begin
        current_base <= (y > 16'd256) ? 16'd256 : y;
        state <= CHECK_BASE;
      end
      
      CHECK_BASE: begin
        if (current_base < 16'd2) begin
          done <= 1'b1;
          state <= IDLE;
        end else begin
          temp_y <= y;
          formed_number <= 55'b0;
          digit_valid <= 1'b1;
          digit_count <= 5'b0;
          state <= DECOMPOSE;
        end
      end
      
      DECOMPOSE: begin
        if (digit > 9) digit_valid <= 1'b0;
        formed_number <= formed_number * 55'd10 + {39'b0, digit};
        temp_y <= next_temp_y;
        digit_count <= digit_count + 5'b1;
        if (next_temp_y == 16'b0 || digit_count == 5'd15) state <= CHECK_VALID;
        else state <= DECOMPOSE;
      end
      
      CHECK_VALID: begin
        if (digit_valid && formed_number >= l_ext) begin
          b <= current_base;
          done <= 1'b1;
          state <= IDLE;
        end else begin
          current_base <= current_base - 16'b1;
          state <= CHECK_BASE;
        end
      end
    endcase
  end
end

endmodule