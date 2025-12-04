module histogram(
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input last_char,
  output reg [25:0] max_letters,
  output reg [4:0] max_count,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    COUNTING,
    COMPUTE_MAX1,
    COMPUTE_MAX2
  } state_t;

  state_t state, next_state;
  reg [4:0] letter_count [0:25];
  reg [3:0] char_count;
  reg [4:0] max_count_reg;
  wire [4:0] temp_max;
  wire [25:0] max_letters_tmp;
  wire is_letter = (char_in >= 8'h61) && (char_in <= 8'h7A);
  wire [4:0] idx = char_in - 8'h61;

  always_comb begin
    temp_max = 5'd0;
    for (int i = 0; i < 26; i++) begin
      if (letter_count[i] > temp_max)
        temp_max = letter_count[i];
    end
  end

  always_comb begin
    for (int i = 0; i < 26; i++) begin
      max_letters_tmp[i] = (letter_count[i] == max_count_reg);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_count <= 4'd0;
      done <= 1'b0;
      max_count <= 5'd0;
      max_letters <= 26'd0;
      foreach (letter_count[i]) letter_count[i] <= 5'd0;
    end else begin
      done <= 1'b0;
      case (state)
        IDLE: begin
          if (start) begin
            state <= COUNTING;
            char_count <= 4'd0;
            foreach (letter_count[i]) letter_count[i] <= 5'd0;
            max_letters <= 26'd0;
            max_count <= 5'd0;
          end
        end

        COUNTING: begin
          if (last_char || (char_count >= 16)) begin
            state <= COMPUTE_MAX1;
          end else if (is_letter) begin
            letter_count[idx] <= letter_count[idx] + 1'd1;
            char_count <= char_count + 1'd1;
            if (char_count + 1'd1 >= 16)
              state <= COMPUTE_MAX1;
          end
        end

        COMPUTE_MAX1: begin
          max_count_reg <= temp_max;
          state <= COMPUTE_MAX2;
        end

        COMPUTE_MAX2: begin
          max_letters <= max_letters_tmp;
          max_count <= max_count_reg;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule