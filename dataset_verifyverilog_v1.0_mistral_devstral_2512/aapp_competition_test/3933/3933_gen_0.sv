module weather_prediction(
    input clk,
    input rst_n,
    input start,
    input signed [10:0] data_in,
    input [6:0] n,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] READING = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [6:0] counter;
    reg signed [10:0] t0;
    reg signed [10:0] t1;
    reg signed [10:0] last_temp;
    reg signed [11:0] d;
    reg arithmetic_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 7'd0;
            t0 <= 11'd0;
            t1 <= 11'd0;
            last_temp <= 11'd0;
            d <= 12'd0;
            arithmetic_flag <= 1'b1;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= READING;
                        counter <= 7'd0;
                        t0 <= data_in;
                        arithmetic_flag <= 1'b1;
                    end
                end

                READING: begin
                    if (counter == 7'd0) begin
                        // First temperature already stored as t0
                        t1 <= data_in;
                        d <= t1 - t0;
                        last_temp <= t1;
                        counter <= counter + 7'd1;
                    end else if (counter == 7'd1) begin
                        // Second temperature already stored as t1
                        last_temp <= data_in;
                        if (last_temp - t1 != d) begin
                            arithmetic_flag <= 1'b0;
                        end
                        counter <= counter + 7'd1;
                    end else begin
                        // Subsequent temperatures
                        if (arithmetic_flag) begin
                            if (data_in - last_temp != d) begin
                                arithmetic_flag <= 1'b0;
                            end
                        end
                        last_temp <= data_in;
                        counter <= counter + 7'd1;
                        
                        // Check if we've read all n temperatures
                        if (counter == n - 7'd1) begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    if (arithmetic_flag) begin
                        result <= {last_temp[10], last_temp} + d;
                    end else begin
                        result <= {last_temp[10], last_temp};
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule