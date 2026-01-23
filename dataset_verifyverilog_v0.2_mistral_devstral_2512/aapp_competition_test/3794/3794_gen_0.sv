module split_gcd (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [31:0] data [0:7],
  output reg possible,
  output reg [7:0] mask,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    CHECK_GCD,
    DONE
  } state_t;

  state_t state, next_state;
  reg [7:0] current_mask;
  reg [31:0] gcd_group1, gcd_group2;
  reg [31:0] temp_gcd;
  reg [3:0] mask_index;
  reg [3:0] data_index;
  reg [3:0] gcd_index;
  reg [3:0] group1_count, group2_count;
  reg group1_valid, group2_valid;
  reg [31:0] a, b;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      possible <= 0;
      mask <= 0;
      done <= 0;
      current_mask <= 0;
      gcd_group1 <= 0;
      gcd_group2 <= 0;
      temp_gcd <= 0;
      mask_index <= 0;
      data_index <= 0;
      gcd_index <= 0;
      group1_count <= 0;
      group2_count <= 0;
      group1_valid <= 0;
      group2_valid <= 0;
      a <= 0;
      b <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (current_mask == (1 << n) - 1) begin
          if (possible) next_state = DONE;
          else next_state = IDLE;
        end else begin
          next_state = CHECK_GCD;
        end
      end
      CHECK_GCD: begin
        next_state = PROCESSING;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_mask <= 0;
      gcd_group1 <= 0;
      gcd_group2 <= 0;
      temp_gcd <= 0;
      mask_index <= 0;
      data_index <= 0;
      gcd_index <= 0;
      group1_count <= 0;
      group2_count <= 0;
      group1_valid <= 0;
      group2_valid <= 0;
      a <= 0;
      b <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            current_mask <= 0;
            possible <= 0;
            mask <= 0;
            done <= 0;
          end
        end
        PROCESSING: begin
          if (current_mask == 0) begin
            current_mask <= 1;
          end else begin
            current_mask <= current_mask + 1;
          end
        end
        CHECK_GCD: begin
          // Compute GCD for group1
          group1_count = 0;
          group2_count = 0;
          for (int i = 0; i < n; i++) begin
            if (!current_mask[i]) begin
              group1_count = group1_count + 1;
            end else begin
              group2_count = group2_count + 1;
            end
          end
          group1_valid = (group1_count > 0);
          group2_valid = (group2_count > 0);

          if (group1_valid) begin
            gcd_group1 = data[0];
            for (int i = 1; i < n; i++) begin
              if (!current_mask[i]) begin
                a = gcd_group1;
                b = data[i];
                while (b != 0) begin
                  temp_gcd = b;
                  b = a % b;
                  a = temp_gcd;
                end
                gcd_group1 = a;
              end
            end
          end

          if (group2_valid) begin
            gcd_group2 = data[0];
            for (int i = 1; i < n; i++) begin
              if (current_mask[i]) begin
                a = gcd_group2;
                b = data[i];
                while (b != 0) begin
                  temp_gcd = b;
                  b = a % b;
                  a = temp_gcd;
                end
                gcd_group2 = a;
              end
            end
          end

          if (group1_valid && group2_valid && gcd_group1 == 1 && gcd_group2 == 1) begin
            possible <= 1;
            mask <= current_mask;
            done <= 1;
          end
        end
        DONE: begin
          if (!start) begin
            possible <= 0;
            mask <= 0;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule