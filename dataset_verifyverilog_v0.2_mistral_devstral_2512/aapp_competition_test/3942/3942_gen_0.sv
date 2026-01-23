module treasure_map_solver (
  input clk,
  input rst_n,
  input start,
  input [5:0] str_len,
  input [255:0] str_data,
  output reg [4:0] sharp_count,
  output reg [31:0] result_packed,
  output reg valid,
  output reg error
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COUNT,
    VALIDATE,
    DONE
  } state_t;

  state_t state;
  reg [5:0] index;
  reg [5:0] open_count;
  reg [5:0] close_count;
  reg [4:0] sharp_count_reg;
  reg [5:0] balance;
  reg [5:0] diff;
  reg [4:0] sharp_index;
  reg [5:0] sharp_positions [0:4];
  reg [5:0] sharp_values [0:4];
  reg [5:0] temp_balance;
  reg [5:0] last_sharp_value;

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 0;
      open_count <= 0;
      close_count <= 0;
      sharp_count_reg <= 0;
      balance <= 0;
      diff <= 0;
      sharp_index <= 0;
      for (int i = 0; i < 5; i++) begin
        sharp_positions[i] <= 0;
        sharp_values[i] <= 0;
      end
      temp_balance <= 0;
      last_sharp_value <= 0;
      sharp_count <= 0;
      result_packed <= 0;
      valid <= 0;
      error <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COUNT;
            index <= 0;
            open_count <= 0;
            close_count <= 0;
            sharp_count_reg <= 0;
            balance <= 0;
            error <= 0;
            valid <= 0;
            sharp_index <= 0;
            for (int i = 0; i < 5; i++) begin
              sharp_positions[i] <= 0;
              sharp_values[i] <= 0;
            end
          end
        end
        COUNT: begin
          if (index < str_len) begin
            // Extract current character
            reg [7:0] current_char = str_data[(index + 1) * 8 - 1: index * 8];
            case (current_char)
              8'h28: open_count <= open_count + 1; // '('
              8'h29: close_count <= close_count + 1; // ')'
              8'h23: begin // '#'
                sharp_count_reg <= sharp_count_reg + 1;
                sharp_positions[sharp_index] <= index;
                sharp_index <= sharp_index + 1;
              end
            endcase
            // Update balance
            if (current_char == 8'h28) balance <= balance + 1;
            else if (current_char == 8'h29) balance <= balance - 1;
            // Check for negative balance
            if (balance < 0) error <= 1;
            index <= index + 1;
          end else begin
            // First pass complete
            diff <= open_count - close_count - sharp_count_reg;
            if (diff < 0) error <= 1;
            else begin
              // Assign values to '#'
              for (int i = 0; i < sharp_count_reg; i++) begin
                if (i == sharp_count_reg - 1) sharp_values[i] <= diff + 1;
                else sharp_values[i] <= 1;
              end
            end
            state <= VALIDATE;
            index <= 0;
            temp_balance <= 0;
          end
        end
        VALIDATE: begin
          if (index < str_len) begin
            reg [7:0] current_char = str_data[(index + 1) * 8 - 1: index * 8];
            // Check if current character is a '#'
            reg is_sharp = 0;
            reg [4:0] sharp_pos = 0;
            for (int i = 0; i < sharp_count_reg; i++) begin
              if (sharp_positions[i] == index) begin
                is_sharp = 1;
                sharp_pos = i;
              end
            end
            // Update balance
            if (current_char == 8'h28) temp_balance <= temp_balance + 1;
            else if (current_char == 8'h29) temp_balance <= temp_balance - 1;
            else if (is_sharp) temp_balance <= temp_balance - sharp_values[sharp_pos];
            // Check for negative balance
            if (temp_balance < 0) error <= 1;
            index <= index + 1;
          end else begin
            // Validation complete
            if (!error) begin
              // Pack results
              result_packed <= 0;
              for (int i = 0; i < sharp_count_reg; i++) begin
                result_packed[(i + 1) * 6 - 1: i * 6] <= sharp_values[i];
              end
              valid <= 1;
            end else begin
              result_packed <= 0;
              valid <= 0;
            end
            state <= DONE;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            valid <= 0;
          end
        end
      endcase
    end
  end

  // Output assignments
  always @(posedge clk) begin
    sharp_count <= sharp_count_reg;
  end

endmodule