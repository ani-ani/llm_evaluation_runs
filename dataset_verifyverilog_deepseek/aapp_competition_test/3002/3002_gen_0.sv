module service_verifier(
  input clk,
  input rst_n,
  input start,
  input [4:0][15:0] years_months,
  input [4:0][16:0] odos,
  output reg [1:0] status
);

  reg [3:0] counter;
  reg [2:0] index;
  reg [15:0] prev_months;
  reg [16:0] prev_odo;
  reg prev_valid;
  reg insufficient_flag;
  reg tampered_flag;
  
  enum {IDLE, PROCESS} state;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      status <= 2'b00;
      counter <= 4'd0;
      index <= 3'd0;
      prev_months <= 16'd0;
      prev_odo <= 17'd0;
      prev_valid <= 1'b0;
      insufficient_flag <= 1'b0;
      tampered_flag <= 1'b0;
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            counter <= 4'd0;
            index <= 3'd0;
            prev_months <= 16'd0;
            prev_odo <= 17'd0;
            prev_valid <= 1'b0;
            insufficient_flag <= 1'b0;
            tampered_flag <= 1'b0;
            status <= 2'b00;
            state <= PROCESS;
          end
        end
        
        PROCESS: begin
          counter <= counter + 1;
          if (counter < 5) begin
            if (years_months[index][15]) begin
              reg [6:0] year_offset = years_months[index][14:8];
              reg [7:0] month_val = years_months[index][7:0];
              reg [15:0] months_total = (year_offset * 12) + (month_val - 1);
              reg [16:0] curr_odo = odos[index];
              
              if (prev_valid) begin
                reg signed [16:0] delta_month_signed = months_total - prev_months;
                if (delta_month_signed < 1) begin
                  tampered_flag <= 1'b1;
                end else begin
                  reg [16:0] delta_month = delta_month_signed;
                  reg [16:0] delta_odo;
                  if (curr_odo >= prev_odo) begin
                    delta_odo = curr_odo - prev_odo;
                  end else begin
                    delta_odo = 100000 - prev_odo + curr_odo;
                  end
                  
                  reg [21:0] min_km = 2000 * delta_month;
                  reg [21:0] max_km = 20000 * delta_month;
                  if (delta_odo < min_km || delta_odo > max_km) begin
                    tampered_flag <= 1'b1;
                  end
                  if (delta_odo > 30000 && delta_month > 12) begin
                    insufficient_flag <= 1'b1;
                  end
                end
              end
              prev_months <= months_total;
              prev_odo <= curr_odo;
              prev_valid <= 1'b1;
            end
            index <= index + 1;
          end
          
          if (counter == 9) begin
            if (tampered_flag) status <= 2'b10;
            else if (insufficient_flag) status <= 2'b01;
            else status <= 2'b00;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule