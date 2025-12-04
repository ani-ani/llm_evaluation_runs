module lunch_bill_processor(
  input clk,
  input rst_n,
  input start,
  input [7:0] P,
  output reg [7:0] B_out,
  output reg [7:0] M_out,
  output reg valid,
  output reg done,
  output reg [7:0] count
);

  localparam [1:0] IDLE = 2'b00,
                   COMPUTE = 2'b01,
                   DONE = 2'b10;

  reg [1:0] state;
  reg [3:0] P_hund, P_tens, P_units;
  reg [7:0] current_B;

  function automatic [3:0] get_hundreds(input [7:0] val);
    get_hundreds = val / 100;
  endfunction

  function automatic [3:0] get_tens(input [7:0] val);
    get_tens = (val % 100) / 10;
  endfunction

  function automatic [3:0] get_units(input [7:0] val);
    get_units = val % 10;
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 8'b0;
      done <= 1'b0;
      valid <= 1'b0;
      B_out <= 8'b0;
      M_out <= 8'b0;
      current_B <= 8'b0;
      P_hund <= 4'b0;
      P_tens <= 4'b0;
      P_units <= 4'b0;
    end else begin
      valid <= 1'b0;
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            P_hund <= get_hundreds(P);
            P_tens <= get_tens(P);
            P_units <= get_units(P);
            current_B <= 8'd1;
            count <= 8'd0;
            state <= COMPUTE;
          end
        end

        COMPUTE: begin
          if (current_B < (P - current_B)) begin
            automatic reg [3:0] B_hund = get_hundreds(current_B);
            automatic reg [3:0] B_tens = get_tens(current_B);
            automatic reg [3:0] B_unit = get_units(current_B);
            automatic reg [3:0] M_hund = get_hundreds(P - current_B);
            automatic reg [3:0] M_tens = get_tens(P - current_B);
            automatic reg [3:0] M_unit = get_units(P - current_B);
            automatic reg duplicate = 1'b0;
            automatic reg [9:0] flags = 10'b0;
            automatic reg [3:0] digits [8:0] = '{P_hund, P_tens, P_units, 
                                               B_hund, B_tens, B_unit,
                                               M_hund, M_tens, M_unit};

            for (int i = 0; i < 9; i++) begin
              if (flags[digits[i]]) duplicate = 1'b1;
              else flags[digits[i]] = 1'b1;
            end

            if (!duplicate) begin
              valid <= 1'b1;
              B_out <= current_B;
              M_out <= P - current_B;
              count <= count + 8'd1;
            end
          end

          current_B <= current_B + 8'd1;
          if (current_B + 8'd1 >= (P - (current_B + 8'd1))) begin
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          if (start) state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule