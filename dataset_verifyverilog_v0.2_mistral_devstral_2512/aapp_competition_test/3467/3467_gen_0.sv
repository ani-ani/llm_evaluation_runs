module tram_scheduling (
    input clk,
    input rst_n,
    input start,
    input [7:0] s,
    input [7:0] num_stops,
    input [7:0] num_lines,
    input [7:0] t0 [0:7],
    input [7:0] p [0:7],
    input [7:0] d [0:7],
    input [2:0] u [0:7],
    input [2:0] v [0:7],
    output reg [7:0] latest_departure,
    output reg valid,
    output reg impossible
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        PROCESSING,
        UPDATE,
        DONE
    } state_t;

    state_t state;
    reg [7:0] latest_arrival [0:7];
    reg [3:0] iteration;
    reg [3:0] line_idx;
    reg [7:0] target_time;
    reg [7:0] temp_departure;
    reg [7:0] k;
    reg [7:0] remainder;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            iteration <= 0;
            line_idx <= 0;
            valid <= 0;
            impossible <= 0;
            latest_departure <= 0;
            for (int i = 0; i < 8; i++) begin
                latest_arrival[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        valid <= 0;
                        impossible <= 0;
                    end
                end

                INIT: begin
                    // Initialize latest_arrival array
                    for (int i = 0; i < 8; i++) begin
                        if (i == num_stops - 1) begin
                            latest_arrival[i] <= s;
                        end else begin
                            latest_arrival[i] <= 0;
                        end
                    end
                    iteration <= 0;
                    line_idx <= 0;
                    state <= PROCESSING;
                end

                PROCESSING: begin
                    if (iteration < 8) begin
                        line_idx <= 0;
                        state <= UPDATE;
                    end else begin
                        state <= DONE;
                    end
                end

                UPDATE: begin
                    if (line_idx < num_lines) begin
                        // Process current tram line
                        target_time = latest_arrival[v[line_idx]];
                        if (target_time > 0 && target_time > d[line_idx]) begin
                            // Calculate latest valid departure
                            if (target_time - d[line_idx] >= t0[line_idx]) begin
                                remainder = (target_time - d[line_idx] - t0[line_idx]) % p[line_idx];
                                k = (target_time - d[line_idx] - t0[line_idx] - remainder) / p[line_idx];
                                temp_departure = t0[line_idx] + k * p[line_idx];
                                
                                // Update latest_arrival for source stop
                                if (temp_departure + d[line_idx] > latest_arrival[u[line_idx]]) begin
                                    latest_arrival[u[line_idx]] <= temp_departure + d[line_idx];
                                end
                            end
                        end
                        line_idx <= line_idx + 1;
                    end else begin
                        iteration <= iteration + 1;
                        state <= PROCESSING;
                    end
                end

                DONE: begin
                    if (latest_arrival[0] > 0) begin
                        latest_departure <= latest_arrival[0];
                        valid <= 1;
                        impossible <= 0;
                    end else begin
                        latest_departure <= 0;
                        valid <= 0;
                        impossible <= 1;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule