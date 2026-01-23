module bookcase_optimizer (
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [2:0] num_books,
  input reg [7:0] heights [0:7],
  input reg [7:0] thickness [0:7],
  output reg [15:0] min_area,
  output reg done
);

  localparam integer IDLE = 3'd0, PREPROCESS =3'd1, BRUTE_FORCE_CHECK=3'd2, UPDATE_MIN=3'd3, DONE=3'd4;
  localparam integer POWER3_0 =1, POWER3_1=3, POWER3_2=9, POWER3_3=27, POWER3_4=81, POWER3_5=243, POWER3_6=729, POWER3_7=2187;

  reg [2:0] state;
  reg [15:0] assignment_counter;
  reg [15:0] min_area;
  reg [15:0] total_iterations;
  reg [2:0] num_books_reg;
  reg [7:0] heights_reg [0:7];
  reg [7:0] thickness_reg [0:7];
  reg [15:0] max_h_shelf [2:0];
  reg [15:0] total_t_shelf [2:0];

  always @(*) begin
      state <= state;
      case (state)
          IDLE: begin
              if (!rst_n) begin
                  state <= IDLE;
                  assignment_counter <=16'd0;
                  min_area <=16'd65535;
                  total_iterations <=16'd1;
                  num_books_reg <=3'd0;
                  max_h_shelf <= {16'd0,16'd0,16'd0};
                  total_t_shelf <= {16'd0,16'd0,16'd0};
              end else if (start) begin
                  state <= PREPROCESS;
              end else begin
                  state <= IDLE;
              end
          end

          PREPROCESS: begin
              if (!rst_n) begin
                  num_books_reg <= num_books;
                  heights_reg <= heights;
                  thickness_reg <= thickness;
                  case (num_books_reg)
                      3: total_iterations <=27;
                      4: total_iterations <=81;
                      5: total_iterations <=243;
                      6: total_iterations <=729;
                      7: total_iterations <=2187;
                      8: total_iterations <=6561;
                      default: total_iterations <=1;
                  endcase
                  state <= BRUTE_FORCE_CHECK;
              end else begin
                  state <= BRUTE_FORCE_CHECK;
              end
          end

          BRUTE_FORCE_CHECK: begin
              if (assignment_counter < total_iterations) begin
                  assignment_counter <= assignment_counter +1;
                  state <= BRUTE_FORCE_CHECK;
              end else begin
                  state <= UPDATE_MIN;
              end
          end

          UPDATE_MIN: state <= DONE;
          DONE: begin
              state <= DONE;
          end
      endcase
  end

  always @(posedge clk) begin
      if (!rst_n) begin
          state <= IDLE;
          assignment_counter <=16'd0;
          min_area <=16'd65535;
          total_iterations <=16'd1;
          num_books_reg <=3'd0;
          max_h_shelf <= {16'd0,16'd0,16'd0};
          total_t_shelf <= {16'd0,16'd0,16'd0};
      end
  end

  done = (state == DONE);
endmodule