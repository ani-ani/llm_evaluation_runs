module weather_prediction (
    input clk,
    input rst_n,
    input start,
    input signed [10:0] data_in,
    input [6:0] n,
    output reg signed [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] READING  = 2'd1;
    localparam [1:0] FINISH   = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg signed [10:0] t0_reg;
    reg signed [10:0] t1_reg;
    reg signed [10:0] last_temp;
    reg signed [10:0] d_reg;
    reg [6:0] counter;
    reg arithmetic_flag;
    reg [6:0] max_cycles;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            t0_reg <= 11'sd0;
            t1_reg <= 11'sd0;
            last_temp <= 11'sd0;
            d_reg <= 11'sd0;
            counter <= 7'd0;
            arithmetic_flag <= 1'b1;
            max_cycles <= 7'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 7'd0;
                    arithmetic_flag <= 1'b1;
                    max_cycles <= n;
                    if (start) begin
                        state <= READING;
                    end
                end

                READING: begin
                    counter <= counter + 7'd1;
                    
                    // Store first temperature (t0)
                    if (counter == 7'd0) begin
                        t0_reg <= data_in;
                        last_temp <= data_in;
                    end
                    // Store second temperature (t1) and compute d
                    else if (counter == 7'd1) begin
                        t1_reg <= data_in;
                        d_reg <= data_in - t0_reg;
                        last_temp <= data_in;
                    end
                    // For subsequent temperatures
                    else if (counter >= 7'd2) begin
                        last_temp <= data_in;
                        // Check if difference equals d
                        if ((data_in - last_temp) != d_reg) begin
                            arithmetic_flag <= 1'b0;
                        end
                    end

                    // Check if we've received all temperatures
                    if (counter == (max_cycles - 7'd1)) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Compute result based on arithmetic_flag
                    if (arithmetic_flag && (max_cycles >= 7'd2)) begin
                        // All differences match d, predict next temperature
                        result <= { {5{last_temp[10]}}, last_temp } + { {5{d_reg[10]}}, d_reg };
                    end else begin
                        // Not arithmetic, return last temperature
                        result <= { {5{last_temp[10]}}, last_temp };
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule