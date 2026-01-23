module gold_stores(
    input clk,
    input rst_n,
    input start,
    input [7:0] valid_count,
    input [7:0][15:0] time_array,
    input [7:0][15:0] altitude_array,
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam SORT_PHASE = 3'b010;
    localparam PROCESS_PHASE = 3'b100;
    localparam DONE = 3'b000; // Done state (alternative encoding)

    reg [2:0] state, next_state;
    
    // Sorting and Storage Registers
    reg [15:0] alt [0:7]; // Altitude values
    reg [15:0] times [0:7]; // Time values
    
    // Bubble Sort Registers
    reg [2:0] sort_i; // Outer loop counter (0 to 7)
    reg [2:0] sort_j; // Inner loop counter
    reg [2:0] sort_pass_count; // Tracks number of inner passes
    reg sort_swapped;
    
    // Processing Registers
    reg [15:0] cumulative_time;
    reg [3:0] store_idx; // Index for iterating through stores
    reg [3:0] count_reg; // Store count
    
    // State Register and Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = SORT_PHASE;
                else next_state = IDLE;
            end
            SORT_PHASE: begin
                // Sort is complete when sort_i >= valid_count - 1 (conceptually)
                // Or more accurately, when we've completed the passes
                // Logic: Bubble sort runs for valid_count-1 passes max
                if (sort_i >= valid_count - 1 || valid_count <= 1) 
                    next_state = PROCESS_PHASE;
                else
                    next_state = SORT_PHASE;
            end
            PROCESS_PHASE: begin
                if (store_idx >= valid_count || valid_count == 0)
                    next_state = DONE;
                else
                    next_state = PROCESS_PHASE;
            end
            DONE: begin
                // Stay in DONE until reset or new start
                if (start) next_state = SORT_PHASE;
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            result <= 4'b0;
            done <= 1'b0;
            sort_i <= 3'b0;
            sort_j <= 3'b0;
            sort_pass_count <= 3'b0;
            sort_swapped <= 1'b0;
            cumulative_time <= 16'b0;
            store_idx <= 4'b0;
            count_reg <= 4'b0;
            // Clear arrays
            for (int k = 0; k < 8; k++) begin
                alt[k] <= 16'b0;
                times[k] <= 16'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize arrays from inputs
                        for (int i = 0; i < 8; i++) begin
                            alt[i] <= altitude_array[i];
                            times[i] <= time_array[i];
                        end
                        // Initialize sort counters
                        sort_i <= 3'b0;
                        sort_j <= 3'b0;
                        sort_pass_count <= 3'b0;
                        sort_swapped <= 1'b0;
                    end
                end
                
                SORT_PHASE: begin
                    // Bubble sort implementation
                    if (valid_count > 1) begin
                        // Check if swap needed
                        if (sort_j < valid_count - sort_pass_count - 1) begin
                            if (alt[sort_j] > alt[sort_j + 1]) begin
                                // Swap altitudes
                                alt[sort_j] <= alt[sort_j + 1];
                                alt[sort_j + 1] <= alt[sort_j];
                                // Swap times (parallel swap)
                                times[sort_j] <= times[sort_j + 1];
                                times[sort_j + 1] <= times[sort_j];
                                sort_swapped <= 1'b1;
                            end else begin
                                sort_swapped <= sort_swapped;
                            end
                            sort_j <= sort_j + 1;
                        end else begin
                            // End of this pass
                            if (sort_swapped) begin
                                sort_pass_count <= sort_pass_count + 1;
                                sort_j <= 0;
                                sort_swapped <= 1'b0;
                                sort_i <= sort_i + 1; // Increment pass counter
                            end else begin
                                // No swaps, sort done - force exit
                                sort_i <= valid_count - 1; // Force condition met
                            end
                        end
                    end else begin
                        // If 0 or 1 valid stores, skip sort
                        sort_i <= valid_count - 1;
                    end
                end
                
                PROCESS_PHASE: begin
                    if (store_idx < valid_count) begin
                        // Check if store can be visited
                        if (cumulative_time + times[store_idx] <= alt[store_idx]) begin
                            cumulative_time <= cumulative_time + times[store_idx];
                            count_reg <= count_reg + 1;
                        end
                        store_idx <= store_idx + 1;
                    end
                end
                
                DONE: begin
                    result <= count_reg;
                    done <= 1'b1;
                end
            endcase
            
            // Reset registers when transitioning out of DONE to START
            if (state == DONE && next_state == SORT_PHASE) begin
                cumulative_time <= 16'b0;
                store_idx <= 4'b0;
                count_reg <= 4'b0;
                result <= 4'b0;
                done <= 1'b0;
            end
        end
    end

endmodule
