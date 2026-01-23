module star_wars_movies (
  input clk,
  input rst_n,
  input start,
  input [1:0] query_type,
  input [7:0] query_value,
  output reg [7:0] result,
  output reg done
);

  parameter MAX_MOVIES = 16;
  parameter MAX_QUERIES = 256;

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PROCESS_QUERY,
    INSERT_SHIFT,
    LOOKUP,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Array to store creation indices (1-based)
  reg [7:0] movies [0:MAX_MOVIES-1];
  reg [7:0] n = 0; // Current number of movies

  // Internal registers for processing
  reg [7:0] shift_counter;
  reg [7:0] temp_creation_index;
  reg [7:0] temp_plot_index;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      result <= 0;
      n <= 0;
      shift_counter <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESS_QUERY;
        end
      end

      PROCESS_QUERY: begin
        if (query_type == 1) begin // Insert
          if (n < MAX_MOVIES) begin
            next_state = INSERT_SHIFT;
          end else begin
            next_state = DONE;
          end
        end else if (query_type == 2) begin // Lookup
          next_state = LOOKUP;
        end else begin
          next_state = DONE;
        end
      end

      INSERT_SHIFT: begin
        if (shift_counter < n) begin
          next_state = INSERT_SHIFT;
        end else begin
          next_state = DONE;
        end
      end

      LOOKUP: begin
        next_state = DONE;
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
      done <= 0;
      result <= 0;
      shift_counter <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 0;
        end

        PROCESS_QUERY: begin
          done <= 0;
          if (query_type == 1) begin // Insert
            temp_plot_index = query_value - 1;
            temp_creation_index = n + 1;
            shift_counter <= n;
          end else if (query_type == 2) begin // Lookup
            temp_plot_index = query_value - 1;
          end
        end

        INSERT_SHIFT: begin
          if (shift_counter > temp_plot_index) begin
            movies[shift_counter] <= movies[shift_counter - 1];
            shift_counter <= shift_counter - 1;
          end else if (shift_counter == temp_plot_index) begin
            movies[shift_counter] <= temp_creation_index;
            n <= n + 1;
            shift_counter <= shift_counter - 1;
          end
        end

        LOOKUP: begin
          if (temp_plot_index < n) begin
            result <= movies[temp_plot_index];
          end else begin
            result <= 0;
          end
        end

        DONE: begin
          done <= 1;
        end

        default: begin
          done <= 0;
        end
      endcase
    end
  end

endmodule