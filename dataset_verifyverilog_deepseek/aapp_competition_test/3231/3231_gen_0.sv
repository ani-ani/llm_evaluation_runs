module friendship_validator(input clk, rst_n, start, input [3:0] n, p, q, input [7:0] friends [0:7], output reg decision, done);

  reg [3:0] counter;
  reg symmetry_fail, friend_exceed;
  reg state;
  localparam IDLE = 0, PROCESSING = 1;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 0;
      done <= 0;
      decision <= 0;
      symmetry_fail <= 0;
      friend_exceed <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            counter <= 0;
            symmetry_fail <= 0;
            friend_exceed <= 0;
            done <= 0;
            decision <= 0;
          end
        end
        PROCESSING: begin
          if (counter < n) begin
            for (int j = counter + 1; j < n; j++) begin
              if (friends[counter][j] != friends[j][counter]) symmetry_fail <= 1'b1;
            end
            automatic reg [3:0] friend_count = 0;
            for (int j = 0; j < n; j++) begin
              friend_count += friends[counter][j];
            end
            if (friend_count > (p - 1) + q) friend_exceed <= 1'b1;
            counter <= counter + 1;
          end
          else if (counter == n) begin
            decision <= symmetry_fail || friend_exceed;
            counter <= counter + 1;
          end
          else if (counter == n + 1) begin
            done <= 1'b1;
            state <= IDLE;
            counter <= 0;
          end
        end
      endcase
    end
  end

endmodule