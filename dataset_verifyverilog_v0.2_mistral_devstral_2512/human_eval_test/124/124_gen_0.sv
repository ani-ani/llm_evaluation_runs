module date_validator (
  input clk,
  input rst_n,
  input start,
  input [79:0] date_str,
  output reg valid,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PARSE,
    CHECK_FORMAT,
    CHECK_MONTH,
    CHECK_DAY,
    DONE
  } state_t;

  state_t state;
  reg [3:0] month, day;
  reg [11:0] year;
  reg [7:0] m1, m2, d1, d2, y1, y2, y3, y4;
  reg sep1_valid, sep2_valid;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      valid <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PARSE;
            valid <= 0;
            done <= 0;
          end
        end
        PARSE: begin
          // Extract ASCII characters
          m1 <= date_str[7:0];
          m2 <= date_str[15:8];
          d1 <= date_str[31:24];
          d2 <= date_str[39:32];
          y1 <= date_str[55:48];
          y2 <= date_str[63:56];
          y3 <= date_str[71:64];
          y4 <= date_str[79:72];
          state <= CHECK_FORMAT;
        end
        CHECK_FORMAT: begin
          // Check separators are '-'
          sep1_valid = (date_str[23:16] == 8'h2D);
          sep2_valid = (date_str[47:40] == 8'h2D);
          
          // Check all characters are digits
          if (sep1_valid && sep2_valid &&
              m1 >= 8'h30 && m1 <= 8'h39 &&
              m2 >= 8'h30 && m2 <= 8'h39 &&
              d1 >= 8'h30 && d1 <= 8'h39 &&
              d2 >= 8'h30 && d2 <= 8'h39 &&
              y1 >= 8'h30 && y1 <= 8'h39 &&
              y2 >= 8'h30 && y2 <= 8'h39 &&
              y3 >= 8'h30 && y3 <= 8'h39 &&
              y4 >= 8'h30 && y4 <= 8'h39) begin
            // Convert ASCII to binary
            month = (m1 - 8'h30) * 10 + (m2 - 8'h30);
            day = (d1 - 8'h30) * 10 + (d2 - 8'h30);
            year = (y1 - 8'h30) * 1000 + (y2 - 8'h30) * 100 + (y3 - 8'h30) * 10 + (y4 - 8'h30);
            state <= CHECK_MONTH;
          end else begin
            valid <= 0;
            state <= DONE;
          end
        end
        CHECK_MONTH: begin
          // Check month is 1-12
          if (month >= 1 && month <= 12) begin
            state <= CHECK_DAY;
          end else begin
            valid <= 0;
            state <= DONE;
          end
        end
        CHECK_DAY: begin
          // Check day based on month
          if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) begin
            valid <= (day >= 1 && day <= 31);
          end else if (month == 4 || month == 6 || month == 9 || month == 11) begin
            valid <= (day >= 1 && day <= 30);
          end else if (month == 2) begin
            valid <= (day >= 1 && day <= 29);
          end else begin
            valid <= 0;
          end
          state <= DONE;
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule