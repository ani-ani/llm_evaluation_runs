module knight_pathfinder(
  input clk, 
  input rst_n, 
  input start, 
  input [7:0] num_cards, 
  input [15:0] card_data [0:255][0:4], 
  output reg [15:0] min_cost, 
  output reg done
);

  typedef enum logic [2:0] {IDLE, INIT, PROCESS, EXPAND, DONE} state_t;
  state_t current_state, next_state;
  reg signed [15:0] start_r, start_c;

  // State storage
  typedef struct packed {
    logic signed [15:0] r;
    logic signed [15:0] c;
    logic [255:0] collected;
    logic [15:0] cost;
  } queue_entry_t;
  localparam QUEUE_SIZE = 256;
  queue_entry_t queue [QUEUE_SIZE-1:0];
  reg [QUEUE_SIZE-1:0] queue_valid;
  reg [7:0] queue_count;
  queue_entry_t current;

  // Expansion counters
  reg [7:0] card_index;
  reg [2:0] move_dir;
  reg signed [15:0] new_r, new_c;
  reg [255:0] new_collected;
  reg [15:0] new_cost;
  logic [15:0] p;
  logic found_card;
  reg [7:0] found_index;

  // Visit tracking (simplified)
  reg [255:0] visited [QUEUE_SIZE-1:0];
  reg signed [15:0] visited_r [QUEUE_SIZE-1:0];
  reg signed [15:0] visited_c [QUEUE_SIZE-1:0];
  reg [15:0] visited_cost [QUEUE_SIZE-1:0];
  reg [QUEUE_SIZE-1:0] visited_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      min_cost <= 16'hFFFF;
      queue_valid <= '0;
      visited_valid <= '0;
      queue_count <= 0;
    end else begin
      unique case (current_state)
        IDLE: begin
          if (start) begin
            start_r <= card_data[0][0];
            start_c <= card_data[0][1];
            current_state <= INIT;
          end
        end

        INIT: begin
          queue[0].r <= start_r;
          queue[0].c <= start_c;
          queue[0].collected <= 256'b1;
          queue[0].cost <= 0;
          queue_valid[0] <= 1;
          queue_count <= 1;
          current_state <= PROCESS;
        end

        PROCESS: begin
          if (queue_count == 0) begin
            done <= 1;
            current_state <= DONE;
          end else begin
            // Priority queue extraction
            int min_index = QUEUE_SIZE;
            logic [15:0] min_cost_val = 16'hFFFF;
            for (int i = 0; i < QUEUE_SIZE; i++) begin
              if (queue_valid[i]) begin
                if ((min_index == QUEUE_SIZE) || (queue[i].cost < min_cost_val)) begin
                  min_cost_val = queue[i].cost;
                  min_index = i;
                end
              end
            end

            if (min_index != QUEUE_SIZE) begin
              current <= queue[min_index];
              queue_valid[min_index] <= 0;
              queue_count <= queue_count - 1;

              // Goal check
              if (current.r == 0 && current.c == 0) begin
                min_cost <= current.cost;
                done <= 1;
                current_state <= DONE;
              end else begin
                current_state <= EXPAND;
                card_index <= 0;
              end
            end else begin
              done <= 1;
              current_state <= DONE;
            end
          end
        end

        EXPAND: begin
          if (card_index < 8'd255) begin
            if (current.collected[card_index] && card_index < num_cards) begin
              move_dir <= 0;
              current_state <= EXPAND_CARD;
            end else begin
              card_index <= card_index + 1;
            end
          end else begin
            current_state <= PROCESS;
          end
        end

        EXPAND_CARD: begin
          if (move_dir < 8) begin
            p <= card_data[card_index][4];
            new_r <= current.r;
            new_c <= current.c;
            case (move_dir)
              0: begin
                new_r <= current.r + $signed(card_data[card_index][2]);
                new_c <= current.c + $signed(card_data[card_index][3]);
              end
              1: begin
                new_r <= current.r + $signed(card_data[card_index][2]);
                new_c <= current.c - $signed(card_data[card_index][3]);
              end
              2: begin
                new_r <= current.r - $signed(card_data[card_index][2]);
                new_c <= current.c + $signed(card_data[card_index][3]);
              end
              3: begin
                new_r <= current.r - $signed(card_data[card_index][2]);
                new_c <= current.c - $signed(card_data[card_index][3]);
              end
              4: begin
                new_r <= current.r + $signed(card_data[card_index][3]);
                new_c <= current.c + $signed(card_data[card_index][2]);
              end
              5: begin
                new_r <= current.r + $signed(card_data[card_index][3]);
                new_c <= current.c - $signed(card_data[card_index][2]);
              end
              6: begin
                new_r <= current.r - $signed(card_data[card_index][3]);
                new_c <= current.c + $signed(card_data[card_index][2]);
              end
              7: begin
                new_r <= current.r - $signed(card_data[card_index][3]);
                new_c <= current.c - $signed(card_data[card_index][2]);
              end
            endcase
            new_collected <= current.collected;
            new_cost <= current.cost + p;
            move_dir <= move_dir + 1;
            current_state <= CHECK_CARD;
          end else begin
            card_index <= card_index + 1;
            current_state <= EXPAND;
          end
        end

        CHECK_CARD: begin
          found_card = 0;
          found_index = num_cards;
          for (int i = 0; i < num_cards; i++) begin
            if ((new_r == $signed(card_data[i][0])) && (new_c == $signed(card_data[i][1])) && !new_collected[i]) begin
              found_card = 1;
              found_index = i;
            end
          end
          if (found_card) new_collected[found_index] <= 1;
          current_state <= UPDATE_STATE;
        end

        UPDATE_STATE: begin
          // Visit optimization (simplified)
          logic duplicate;
          duplicate = 0;
          for (int i = 0; i < QUEUE_SIZE; i++) begin
            if (visited_valid[i] && visited_r[i] == new_r && visited_c[i] == new_c &&
                visited[i] == new_collected && visited_cost[i] <= new_cost) begin
              duplicate = 1;
              break;
            end
          end
          if (!duplicate && queue_count < QUEUE_SIZE) begin
            // Add to queue
            for (int i = 0; i < QUEUE_SIZE; i++) begin
              if (!queue_valid[i]) begin
                queue_valid[i] <= 1;
                queue[i].r <= new_r;
                queue[i].c <= new_c;
                queue[i].collected <= new_collected;
                queue[i].cost <= new_cost;
                queue_count <= queue_count + 1;
                visited_valid[i] <= 1;
                visited_r[i] <= new_r;
                visited_c[i] <= new_c;
                visited[i] <= new_collected;
                visited_cost[i] <= new_cost;
                break;
              end
            end
          end
          current_state <= EXPAND_CARD;
        end

        DONE: begin
          // Hold state until reset
        end
      endcase
    end
  end
endmodule