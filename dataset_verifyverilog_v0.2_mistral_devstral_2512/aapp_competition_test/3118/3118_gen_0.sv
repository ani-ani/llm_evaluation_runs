module shuffling_game(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0][7:0] alice_perm,
  input [7:0][7:0] bob_perm,
  output reg [15:0] result,
  output reg done
);

  // State machine states
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] INITIAL_CHECK = 3'b001;
  localparam [2:0] SHUFFLE = 3'b010;
  localparam [2:0] CHECK_IDENTITY = 3'b011;
  localparam [2:0] DONE = 3'b100;
  localparam [2:0] HUGE = 3'b101;

  reg [2:0] state;
  reg [7:0] card_pos [0:7]; // card_pos[i] = position of card i (0-indexed)
  reg [7:0] step_count;
  reg [7:0] i;
  reg is_identity;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 16'h0;
      done <= 1'b0;
      step_count <= 8'h0;
      for (i = 0; i < 8; i = i + 1) begin
        card_pos[i] <= i;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INITIAL_CHECK;
            done <= 1'b0;
            step_count <= 8'h0;
          end
        end

        INITIAL_CHECK: begin
          // Check if initial state is identity (should be, but verify)
          is_identity = 1'b1;
          for (i = 0; i < n; i = i + 1) begin
            if (card_pos[i] != i) begin
              is_identity = 1'b0;
            end
          end
          if (is_identity) begin
            result <= 16'h0; // 0 shuffles needed
            state <= DONE;
          end else begin
            state <= SHUFFLE;
          end
        end

        SHUFFLE: begin
          step_count <= step_count + 1'b1;
          if (step_count[7]) begin // step_count > 128
            result <= 16'hFFFF;
            state <= HUGE;
          end else begin
            // Apply permutation based on step count parity
            if (step_count[0]) begin // odd step: Alice
              for (i = 0; i < n; i = i + 1) begin
                card_pos[i] <= alice_perm[card_pos[i]];
              end
            end else begin // even step: Bob
              for (i = 0; i < n; i = i + 1) begin
                card_pos[i] <= bob_perm[card_pos[i]];
              end
            end
            state <= CHECK_IDENTITY;
          end
        end

        CHECK_IDENTITY: begin
          is_identity = 1'b1;
          for (i = 0; i < n; i = i + 1) begin
            if (card_pos[i] != i) begin
              is_identity = 1'b0;
            end
          end
          if (is_identity) begin
            result <= {8'h0, step_count};
            state <= DONE;
          end else begin
            state <= SHUFFLE;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (start) begin
            state <= INITIAL_CHECK;
            done <= 1'b0;
            step_count <= 8'h0;
            // Reset card positions to identity
            for (i = 0; i < 8; i = i + 1) begin
              card_pos[i] <= i;
            end
          end
        end

        HUGE: begin
          done <= 1'b1;
          if (start) begin
            state <= INITIAL_CHECK;
            done <= 1'b0;
            step_count <= 8'h0;
            // Reset card positions to identity
            for (i = 0; i < 8; i = i + 1) begin
              card_pos[i] <= i;
            end
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule