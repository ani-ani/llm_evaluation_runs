module special_discard_counter (
  input clk,
  input rst_n,
  input start,
  input [63:0] n_items,
  input [3:0] num_special,
  input [63:0] k_page,
  input [15:0][63:0] special_indices,
  output reg [7:0] result,
  output reg done
);

  // States
  typedef enum logic [1:0] {
    IDLE,
    FIND_PAGE,
    REMOVE_ITEMS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] item_idx; // Index of current special item being processed
  reg [63:0] removed_count; // Total items removed so far
  reg [7:0] op_count; // Operation counter
  reg [63:0] current_pos; // Current position of item being checked
  reg [63:0] page_num; // Page number of current position
  reg [3:0] items_to_remove; // Number of items to remove in current operation

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      item_idx <= 0;
      removed_count <= 0;
      op_count <= 0;
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
        if (start) next_state = FIND_PAGE;
      end
      FIND_PAGE: begin
        if (item_idx == num_special) begin
          next_state = DONE;
        end else begin
          current_pos = special_indices[item_idx] - removed_count;
          if (current_pos > n_items) begin
            // Item already removed or beyond total items
            next_state = FIND_PAGE;
          end else begin
            page_num = (current_pos - 1) / k_page;
            // Check if this is the first page with special items
            if (page_num == (special_indices[item_idx] - removed_count - 1) / k_page) begin
              next_state = REMOVE_ITEMS;
            end else begin
              next_state = FIND_PAGE;
            end
          end
        end
      end
      REMOVE_ITEMS: begin
        next_state = FIND_PAGE;
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      item_idx <= 0;
      removed_count <= 0;
      op_count <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            item_idx <= 0;
            removed_count <= 0;
            op_count <= 0;
          end
        end
        FIND_PAGE: begin
          if (item_idx < num_special) begin
            current_pos = special_indices[item_idx] - removed_count;
            if (current_pos <= n_items) begin
              page_num = (current_pos - 1) / k_page;
              // Check if this is the first page with special items
              if (page_num == (special_indices[item_idx] - removed_count - 1) / k_page) begin
                // Count how many items on this page
                items_to_remove = 0;
                for (int i = 0; i < num_special; i++) begin
                  if (special_indices[i] > 0) begin
                    reg [63:0] pos = special_indices[i] - removed_count;
                    if (pos > n_items) continue;
                    reg [63:0] p = (pos - 1) / k_page;
                    if (p == page_num) begin
                      items_to_remove = items_to_remove + 1;
                    end
                  end
                end
                if (items_to_remove > 0) begin
                  op_count = op_count + 1;
                  removed_count = removed_count + items_to_remove;
                end
              end
            end
            item_idx = item_idx + 1;
          end
        end
        REMOVE_ITEMS: begin
          // No additional action needed, handled in FIND_PAGE
        end
        DONE: begin
          result = op_count;
          done = 1;
        end
      endcase
    end
  end

endmodule