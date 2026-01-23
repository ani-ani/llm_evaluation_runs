module wcd_solver (
  input clk,
  input rst_n,
  input start,
  input [31:0] a_i,
  input [31:0] b_i,
  output reg [31:0] result,
  output reg done
);

  // Hardcoded prime factors to check
  localparam [31:0] FACTORS [0:7] = '{32'd2, 32'd3, 32'd5, 32'd7, 32'd11, 32'd13, 32'd17, 32'd19};

  // State machine states
  typedef enum logic [2:0] {
    IDLE,
    FACTOR_FIRST,
    CHECK_PAIR_1,
    CHECK_PAIR_2,
    CHECK_PAIR_3,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Control signals
  reg [7:0] valid_factors;
  reg [2:0] current_factor_index;
  reg [1:0] pair_index;

  // Intermediate storage for first pair
  reg [31:0] a0, b0;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      valid_factors <= 8'b0;
      current_factor_index <= 0;
      pair_index <= 0;
      a0 <= 0;
      b0 <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = FACTOR_FIRST;
      end
      FACTOR_FIRST: begin
        next_state = CHECK_PAIR_1;
      end
      CHECK_PAIR_1: begin
        if (current_factor_index == 7) begin
          if (pair_index == 1) next_state = CHECK_PAIR_2;
          else next_state = CHECK_PAIR_1;
        end
      end
      CHECK_PAIR_2: begin
        if (current_factor_index == 7) begin
          if (pair_index == 2) next_state = CHECK_PAIR_3;
          else next_state = CHECK_PAIR_2;
        end
      end
      CHECK_PAIR_3: begin
        if (current_factor_index == 7) next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_factors <= 8'b0;
      current_factor_index <= 0;
      pair_index <= 0;
      a0 <= 0;
      b0 <= 0;
    end else begin
      case (current_state)
        FACTOR_FIRST: begin
          // Store first pair and initialize valid_factors
          a0 <= a_i;
          b0 <= b_i;
          valid_factors <= 8'b11111111; // All factors initially valid
          current_factor_index <= 0;
          pair_index <= 0;
        end
        CHECK_PAIR_1, CHECK_PAIR_2, CHECK_PAIR_3: begin
          // Check current factor against current pair
          if (current_factor_index < 8) begin
            reg [31:0] factor = FACTORS[current_factor_index];
            reg valid = valid_factors[current_factor_index];
            
            if (valid) begin
              reg divides_a = (a_i % factor) == 0;
              reg divides_b = (b_i % factor) == 0;
              
              if (!divides_a && !divides_b) begin
                valid_factors[current_factor_index] = 0;
              end
            end
            
            // Move to next factor
            current_factor_index <= current_factor_index + 1;
          end else begin
            // Move to next pair
            current_factor_index <= 0;
            pair_index <= pair_index + 1;
          end
        end
        DONE: begin
          // Determine result
          reg [31:0] first_valid = 32'hFFFFFFFF;
          for (int i = 0; i < 8; i++) begin
            if (valid_factors[i]) begin
              first_valid = FACTORS[i];
              break;
            end
          end
          result <= first_valid;
          done <= 1;
        end
        default: begin
          done <= 0;
        end
      endcase
    end
  end

endmodule