module ToyTrainSolver(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [3:0] candy_count [0:15],
    input [3:0] min_dist [0:15],
    output reg [15:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // Internal signals for computation
    reg [15:0] time [0:15];
    reg [15:0] max_time [0:15];
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 4'd0;
            
            // Initialize all result registers
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 16'd0;
            end
            
            // Initialize internal computation registers
            for (i = 0; i < 16; i = i + 1) begin
                max_time[i] <= 16'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    time[j] <= 16'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Compute time for all stations in parallel
                    for (i = 0; i < 16; i = i + 1) begin
                        if (candy_count[i] > 4'd0) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                // Calculate dist(j, i)
                                reg [3:0] dist_ji;
                                if (i >= j) begin
                                    dist_ji = i - j;
                                end else begin
                                    dist_ji = i + n_in - j;
                                end
                                
                                // Calculate time: dist + n*(candy_count-1) + min_dist
                                time[i] = dist_ji + (n_in * (candy_count[i] - 4'd1)) + min_dist[i];
                            end
                        end else begin
                            time[i] = 16'd0;
                        end
                    end
                    
                    // Find max time for each starting station
                    for (i = 0; i < 16; i = i + 1) begin
                        max_time[i] = 16'd0;
                        for (j = 0; j < 16; j = j + 1) begin
                            if (time[j] > max_time[i]) begin
                                max_time[i] = time[j];
                            end
                        end
                    end
                    
                    // Store results
                    for (i = 0; i < 16; i = i + 1) begin
                        result[i] = max_time[i];
                    end
                    
                    // Transition to finish state
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule