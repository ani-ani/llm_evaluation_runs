module animal_sanctuary_restore(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  // Enclosure config (4 enclosures max):
  input [1:0] correct_animal [0:3], // Correct animal type per enclosure (2-bit enum)
  input [1:0] current_count [0:3], // Current animals per enclosure (2-bit, 0-4 animals)
  input [3:0][1:0] current_animals, // Packed 4 slots x 2 bits (max 4 animals total)
  output reg [1:0] result, // 00:FALSE_ALARM, 01:POSSIBLE, 10:IMPOSSIBLE
  output reg done // High when result valid
);

  // State machine states
  localparam IDLE = 2'b00;
  localparam VERIFY_CORRECT = 2'b01;
  localparam BUILD_GRAPH = 2'b10;
  localparam CHECK_CYCLES = 2'b11;

  // Registers for state machine
  reg [1:0] state, next_state;
  
  // Verify Correct state registers
  reg [1:0] cnt_type;
  reg [1:0] cnt_anim;
  reg [1:0] cnt_enc;
  reg [1:0] remain;
  reg [1:0] type_to_enclosure [3:0];
  reg [1:0] current_enclosure [3:0];
  reg [1:0] first_animal_in_enclosure [3:0];
  reg any_incorrect;
  reg done_verify;
  
  // Build Graph state registers
  reg [1:0] i_anim;
  reg [1:0] graph [3:0];
  
  // Check Cycles state registers
  reg [1:0] current_node;
  reg [3:0] visited;
  reg [1:0] steps;
  reg single_cycle;
  reg [1:0] j;

  // Result values
  localparam FALSE_ALARM = 2'b00;
  localparam POSSIBLE = 2'b01;
  localparam IMPOSSIBLE = 2'b10;

  // Sequential logic for state machine
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 2'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic and output logic
  always @(*) begin
    next_state = state;
    done = 1'b0;
    result = 2'b0;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = VERIFY_CORRECT;
          // Initialize registers for VERIFY_CORRECT state
          cnt_type = 2'b0;
          cnt_anim = 2'b0;
          cnt_enc = 2'b0;
          remain = 2'b0;
          any_incorrect = 1'b0;
          done_verify = 1'b0;
        end
      end

      VERIFY_CORRECT: begin
        if (!done_verify) begin
          if (cnt_type < 4) begin
            // Build type_to_enclosure for current type
            for (j = 0; j < 4; j = j + 1) begin
              if (correct_animal[j] == cnt_type) begin
                type_to_enclosure[cnt_type] = j;
              end
            end
            cnt_type = cnt_type + 1;
            if (cnt_type == 4) begin
              // Start assignment phase
              if (cnt_enc < 4) begin
                remain = current_count[cnt_enc];
                if (remain == 0) begin
                  cnt_enc = cnt_enc + 1;
                end else begin
                  // Assign first animal to this enclosure
                  current_enclosure[cnt_anim] = cnt_enc;
                  // Check correctness
                  if (current_animals[cnt_anim] != correct_animal[cnt_enc]) begin
                    any_incorrect = 1'b1;
                  end
                  // Mark first animal in enclosure
                  if (remain == current_count[cnt_enc]) begin
                    first_animal_in_enclosure[cnt_enc] = cnt_anim;
                  end
                  cnt_anim = cnt_anim + 1;
                  remain = remain - 1;
                  if (remain == 0) begin
                    cnt_enc = cnt_enc + 1;
                  end
                end
              end
            end
          end else begin
            // Assignment phase
            if (cnt_anim < 4) begin
              if (remain == 0) begin
                cnt_enc = cnt_enc + 1;
                if (cnt_enc < 4) begin
                  remain = current_count[cnt_enc];
                end
              end
              if (cnt_enc < 4 && remain > 0) begin
                current_enclosure[cnt_anim] = cnt_enc;
                if (current_animals[cnt_anim] != correct_animal[cnt_enc]) begin
                  any_incorrect = 1'b1;
                end
                if (remain == current_count[cnt_enc]) begin
                  first_animal_in_enclosure[cnt_enc] = cnt_anim;
                end
                cnt_anim = cnt_anim + 1;
                remain = remain - 1;
              end
            end else begin
              done_verify = 1'b1;
              if (!any_incorrect) begin
                result = FALSE_ALARM;
                done = 1'b1;
                next_state = IDLE;
              end else begin
                next_state = BUILD_GRAPH;
                // Initialize BUILD_GRAPH registers
                i_anim = 2'b0;
              end
            end
          end
        end
      end

      BUILD_GRAPH: begin
        if (i_anim < 4) begin
          // Build graph edge for current animal
          reg [1:0] target_type;
          reg [1:0] target_enclosure;
          target_type = current_animals[i_anim];
          target_enclosure = type_to_enclosure[target_type];
          graph[i_anim] = first_animal_in_enclosure[target_enclosure];
          i_anim = i_anim + 1;
        end else begin
          next_state = CHECK_CYCLES;
          // Initialize CHECK_CYCLES registers
          current_node = 2'b0;
          visited = 4'b0;
          steps = 2'b0;
          single_cycle = 1'b1;
        end
      end

      CHECK_CYCLES: begin
        if (steps < 4) begin
          if (visited[current_node]) begin
            single_cycle = 1'b0;
          end
          visited[current_node] = 1'b1;
          current_node = graph[current_node];
          steps = steps + 1;
        end else begin
          // Check if we completed a cycle of length 4 and all nodes visited
          if (current_node != 2'b0) begin
            single_cycle = 1'b0;
          end
          for (j = 0; j < 4; j = j + 1) begin
            if (!visited[j]) begin
              single_cycle = 1'b0;
            end
          end
          
          if (single_cycle) begin
            result = POSSIBLE;
          end else begin
            result = IMPOSSIBLE;
          end
          done = 1'b1;
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule
