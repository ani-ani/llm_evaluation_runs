module flight_scheduler(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] m_count,
    input wire [3:0] src [0:31],
    input wire [3:0] dst [0:31],
    input wire [9:0] dep [0:31],
    input wire [9:0] arr [0:31],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] flight_idx;
    reg [3:0] current_src;
    reg [3:0] current_dst;
    reg [9:0] current_dep;
    reg [9:0] current_arr;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // DP state: min_frustration and arrival_time for each country
    reg [31:0] min_frustration [0:15];
    reg [9:0] arrival_time [0:15];
    
    // Initialize DP states
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            flight_idx <= 8'd0;
            cycle_count <= 8'd0;
            result <= 32'd0;
            done <= 1'b0;
            
            // Initialize DP arrays
            for (i = 0; i < 16; i = i + 1) begin
                min_frustration[i] <= 32'd0;
                arrival_time[i] <= 10'd0;
            end
            
            // Country 1 (index 0) starts with 0 frustration
            min_frustration[0] <= 32'd0;
            arrival_time[0] <= 10'd0;
            
            // All other countries start with infinity
            for (i = 1; i < 16; i = i + 1) begin
                min_frustration[i] <= 32'd4294967295; // Max 32-bit value
                arrival_time[i] <= 10'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        flight_idx <= 8'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Load current flight data
                    current_src <= src[flight_idx];
                    current_dst <= dst[flight_idx];
                    current_dep <= dep[flight_idx];
                    current_arr <= arr[flight_idx];
                    
                    // Process flight: update destination if better path found
                    if (min_frustration[current_src] != 32'd4294967295) begin
                        // Calculate wait time
                        reg [9:0] wait_time;
                        if (current_dep >= arrival_time[current_src]) begin
                            wait_time = current_dep - arrival_time[current_src];
                        end else begin
                            wait_time = 10'd0; // No waiting if flight departs before arrival
                        end
                        
                        // Calculate new frustration
                        reg [31:0] new_frustration;
                        new_frustration = min_frustration[current_src] + (wait_time * wait_time);
                        
                        // Update destination if better
                        if (new_frustration < min_frustration[current_dst]) begin
                            min_frustration[current_dst] <= new_frustration;
                            arrival_time[current_dst] <= current_arr;
                        end
                    end
                    
                    // Move to next flight
                    flight_idx <= flight_idx + 8'd1;
                    
                    // Check if all flights processed
                    if (flight_idx == m_count || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Output result (frustration for country 15, assuming it's the destination)
                    result <= min_frustration[15];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule