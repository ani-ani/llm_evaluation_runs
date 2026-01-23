module sublist_histogram (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_sublists,
  input [2:0] sublist_lengths [0:7],
  input [7:0] sublists [0:7][0:7],
  output reg [2:0] output_index,
  output reg [7:0] unique_list [0:7],
  output reg [2:0] list_length,
  output reg [7:0] count,
  output reg output_valid,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_DATA,
    PROCESS,
    OUTPUT,
    DONE
  } state_t;

  state_t state;
  reg [2:0] current_sublist_idx;
  reg [2:0] unique_count;
  reg [2:0] current_unique_idx;
  reg [2:0] compare_idx;
  reg [2:0] element_idx;
  reg [7:0] unique_sublists [0:7][0:7];
  reg [2:0] unique_lengths [0:7];
  reg [7:0] unique_counts [0:7];
  reg [2:0] output_counter;
  reg match_found;

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_sublist_idx <= 0;
      unique_count <= 0;
      current_unique_idx <= 0;
      compare_idx <= 0;
      element_idx <= 0;
      output_counter <= 0;
      match_found <= 0;
      output_index <= 0;
      list_length <= 0;
      count <= 0;
      output_valid <= 0;
      done <= 0;

      // Initialize unique sublists and counts
      for (int i = 0; i < 8; i++) begin
        unique_counts[i] <= 0;
        unique_lengths[i] <= 0;
        for (int j = 0; j < 8; j++) begin
          unique_sublists[i][j] <= 0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_DATA;
            current_sublist_idx <= 0;
            unique_count <= 0;
            output_counter <= 0;
            done <= 0;
            output_valid <= 0;

            // Reset unique sublists and counts
            for (int i = 0; i < 8; i++) begin
              unique_counts[i] <= 0;
              unique_lengths[i] <= 0;
              for (int j = 0; j < 8; j++) begin
                unique_sublists[i][j] <= 0;
              end
            end
          end
        end

        LOAD_DATA: begin
          if (current_sublist_idx < num_sublists) begin
            state <= PROCESS;
            current_unique_idx <= 0;
            compare_idx <= 0;
            element_idx <= 0;
            match_found <= 0;
          end else begin
            state <= OUTPUT;
            output_counter <= 0;
            output_index <= 0;
          end
        end

        PROCESS: begin
          if (!match_found && current_unique_idx < unique_count) begin
            // Compare current sublist with unique_sublists[current_unique_idx]
            if (element_idx == 0) begin
              // Start comparison
              if (sublist_lengths[current_sublist_idx] == unique_lengths[current_unique_idx]) begin
                element_idx <= 1;
              end else begin
                element_idx <= 0;
                current_unique_idx <= current_unique_idx + 1;
              end
            end else if (element_idx <= sublist_lengths[current_sublist_idx]) begin
              if (sublists[current_sublist_idx][element_idx-1] == unique_sublists[current_unique_idx][element_idx-1]) begin
                if (element_idx == sublist_lengths[current_sublist_idx]) begin
                  // Full match found
                  match_found <= 1;
                  unique_counts[current_unique_idx] <= unique_counts[current_unique_idx] + 1;
                end else begin
                  element_idx <= element_idx + 1;
                end
              end else begin
                element_idx <= 0;
                current_unique_idx <= current_unique_idx + 1;
              end
            end else begin
              element_idx <= 0;
              current_unique_idx <= current_unique_idx + 1;
            end
          end else begin
            if (match_found) begin
              // Move to next sublist
              current_sublist_idx <= current_sublist_idx + 1;
              state <= LOAD_DATA;
            end else begin
              // No match found, add as new unique sublist
              if (unique_count < 8) begin
                // Copy sublist to unique_sublists
                for (int i = 0; i < 8; i++) begin
                  if (i < sublist_lengths[current_sublist_idx]) begin
                    unique_sublists[unique_count][i] <= sublists[current_sublist_idx][i];
                  end else begin
                    unique_sublists[unique_count][i] <= 0;
                  end
                end
                unique_lengths[unique_count] <= sublist_lengths[current_sublist_idx];
                unique_counts[unique_count] <= 1;
                unique_count <= unique_count + 1;
              end
              current_sublist_idx <= current_sublist_idx + 1;
              state <= LOAD_DATA;
            end
          end
        end

        OUTPUT: begin
          if (output_counter < unique_count) begin
            output_valid <= 1;
            output_index <= output_counter;
            list_length <= unique_lengths[output_counter];
            count <= unique_counts[output_counter];
            for (int i = 0; i < 8; i++) begin
              unique_list[i] <= unique_sublists[output_counter][i];
            end
            output_counter <= output_counter + 1;
          end else begin
            output_valid <= 0;
            state <= DONE;
            done <= 1;
          end
        end

        DONE: begin
          if (start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule