module string_sublist_sorter (input clk, input rst_n, input start, input [3:0][31:0] sublist_in, output reg [3:0][31:0] sorted_sublist, output reg done);
  reg [3:0][31:0] current_list;
  reg [2:0] counter;

  function logic compare_swap(input [31:0] a, input [31:0] b);
    logic a_empty = (a == 32'd0);
    logic b_empty = (b == 32'd0);
    if (a_empty && b_empty) return 0;
    else if (a_empty) return 1;
    else if (b_empty) return 0;
    else begin
      for (int i=0; i<4; i++) begin
        byte a_char = a[i*8 +: 8];
        byte b_char = b[i*8 +: 8];
        if (a_char < b_char) return 0;
        else if (a_char > b_char) return 1;
      end
      return 0;
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      current_list <= '0;
      sorted_sublist <= '0;
      counter <= 0;
    end else begin
      sorted_sublist <= current_list;
      if (start) begin
        current_list <= sublist_in;
        done <= 0;
        counter <= 0;
      end else if (!done) begin
        if (counter < 6) begin
          counter <= counter + 1;
          case (counter)
            0: begin
              if (compare_swap(current_list[0], current_list[1])) begin
                current_list[0] <= current_list[1];
                current_list[1] <= current_list[0];
              end
              if (compare_swap(current_list[2], current_list[3])) begin
                current_list[2] <= current_list[3];
                current_list[3] <= current_list[2];
              end
            end
            1: begin
              if (compare_swap(current_list[1], current_list[2])) begin
                current_list[1] <= current_list[2];
                current_list[2] <= current_list[1];
              end
            end
            2: begin
              if (compare_swap(current_list[0], current_list[1])) begin
                current_list[0] <= current_list[1];
                current_list[1] <= current_list[0];
              end
              if (compare_swap(current_list[2], current_list[3])) begin
                current_list[2] <= current_list[3];
                current_list[3] <= current_list[2];
              end
            end
            3: begin
              if (compare_swap(current_list[1], current_list[2])) begin
                current_list[1] <= current_list[2];
                current_list[2] <= current_list[1];
              end
            end
            4: begin
              if (compare_swap(current_list[0], current_list[1])) begin
                current_list[0] <= current_list[1];
                current_list[1] <= current_list[0];
              end
              if (compare_swap(current_list[2], current_list[3])) begin
                current_list[2] <= current_list[3];
                current_list[3] <= current_list[2];
              end
            end
            5: begin
              if (compare_swap(current_list[1], current_list[2])) begin
                current_list[1] <= current_list[2];
                current_list[2] <= current_list[1];
              end
              done <= 1;
            end
          endcase
        end
      end
    end
  end
endmodule