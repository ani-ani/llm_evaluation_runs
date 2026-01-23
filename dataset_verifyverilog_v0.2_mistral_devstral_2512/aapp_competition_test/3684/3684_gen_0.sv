module p2p_streaming (
  input clk,
  input rst_n,
  input start,
  input [7:0] p_i [0:3],
  input [7:0] b_i [0:3],
  input [7:0] u_i [0:3],
  input [4:0] C,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    CHECK_BUFFER,
    UPLOAD_CALC,
    VALIDATE,
    UPDATE_RESULT,
    INCREMENT,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [7:0] B; // Current buffer value in Q8.8 format
  reg [7:0] max_B; // Maximum achievable buffer in Q8.8 format
  reg [7:0] user_idx; // Current user index
  reg [7:0] required_upload; // Required upload for current user
  reg [15:0] total_required; // Total required upload across all users
  reg [15:0] total_bandwidth; // Total bandwidth across all users
  reg [7:0] temp_value; // Temporary calculation value

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      B <= 0;
      max_B <= 0;
      user_idx <= 0;
      required_upload <= 0;
      total_required <= 0;
      total_bandwidth <= 0;
      temp_value <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
        else next_state = IDLE;
      end
      INIT: next_state = CHECK_BUFFER;
      CHECK_BUFFER: next_state = UPLOAD_CALC;
      UPLOAD_CALC: begin
        if (user_idx == 3) next_state = VALIDATE;
        else next_state = UPLOAD_CALC;
      end
      VALIDATE: begin
        if (total_required <= total_bandwidth) next_state = UPDATE_RESULT;
        else next_state = INCREMENT;
      end
      UPDATE_RESULT: next_state = INCREMENT;
      INCREMENT: begin
        if (B == 255) next_state = DONE;
        else next_state = CHECK_BUFFER;
      end
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset values already handled in state machine
    end else begin
      case (state)
        INIT: begin
          // Initialize loop variables
          B <= 8'd0; // Start from -128 in Q8.8 format
          max_B <= 8'd0;
          user_idx <= 0;
          total_bandwidth <= u_i[0] + u_i[1] + u_i[2] + u_i[3];
        end
        CHECK_BUFFER: begin
          // Reset per-buffer calculations
          user_idx <= 0;
          total_required <= 0;
        end
        UPLOAD_CALC: begin
          // Calculate required upload for current user
          // required_upload = max(0, B + C + p_i - b_i)
          temp_value = B + C + p_i[user_idx] - b_i[user_idx];
          if (temp_value[15]) // If negative
            required_upload <= 0;
          else
            required_upload <= temp_value[7:0];
          
          total_required <= total_required + required_upload;
          user_idx <= user_idx + 1;
        end
        VALIDATE: begin
          // Check if total required <= total bandwidth
          if (total_required <= total_bandwidth) begin
            // B is achievable
            if (B > max_B) begin
              max_B <= B;
            end
          end
        end
        INCREMENT: begin
          // Try next B value
          B <= B + 1;
        end
        DONE: begin
          result <= max_B;
          done <= 1;
        end
        default: ;
      endcase
    end
  end

endmodule