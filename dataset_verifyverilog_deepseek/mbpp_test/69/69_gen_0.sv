module sublist_checker (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] main_list,
  input [3:0][7:0] sub_list,
  output logic found,
  output logic done
);

logic [7:0][7:0] main_list_reg;
logic [3:0][7:0] sub_list_reg;
logic sub_all_zero;
logic [2:0] main_non_zero_len;
logic [1:0] sub_non_zero_len;
logic running;
logic [3:0] counter;
logic found_next;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    main_list_reg <= '0;
    sub_list_reg <= '0;
    found <= 0;
    done <= 0;
    running <= 0;
    counter <= 0;
  end else begin
    if (start) begin
      main_list_reg <= main_list;
      sub_list_reg <= sub_list;
      running <= 1;
      counter <= 0;
      done <= 0;
      found <= 0;
    end else if (running) begin
      if (counter == 8) begin
        done <= 1;
        running <= 0;
      end else begin
        counter <= counter + 1;
      end
      if (counter == 0) begin
        found <= found_next;
      end
    end
  end
end

assign sub_all_zero = (sub_list_reg[0] == 8'd0) && (sub_list_reg[1] == 8'd0) &&
                     (sub_list_reg[2] == 8'd0) && (sub_list_reg[3] == 8'd0);

always_comb begin
  main_non_zero_len = 3'd8;
  for (int i = 0; i < 8; i++) begin
    if (main_list_reg[i] == 8'd0) begin
      main_non_zero_len = i[2:0];
      break;
    end
  end
  sub_non_zero_len = 2'd4;
  for (int i = 0; i < 4; i++) begin
    if (sub_list_reg[i] == 8'd0) begin
      sub_non_zero_len = i[1:0];
      break;
    end
  end
end

always_comb begin
  found_next = 1'b0;
  if (sub_all_zero) begin
    found_next = 1'b1;
  end else if (sub_non_zero_len > main_non_zero_len) begin
    found_next = 1'b0;
  end else begin
    for (int i = 0; i <= 4; i++) begin
      logic match;
      match = 1'b1;
      for (int j = 0; j < 4; j++) begin
        if (sub_list_reg[j] != main_list_reg[i + j]) begin
          match = 1'b0;
          break;
        end
      end
      if (match) begin
        found_next = 1'b1;
        break;
      end
    end
  end
end

endmodule