module flower_counter #(
    parameter DAYS = 8,
    parameter COORD_WIDTH = 5,
    parameter DAY_WIDTH = 3,
    parameter COUNT_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [COORD_WIDTH-1:0] L_in,
    input wire [COORD_WIDTH-1:0] R_in,
    output reg [COUNT_WIDTH-1:0] new_flowers,
    output reg done
);
    // Internal state: current day counter
    reg [DAY_WIDTH-1:0] day_counter;
    reg [2:0] state;
    
    // Storage for previous plants: 8 days × 5-bit coordinates
    reg [COORD_WIDTH-1:0] L_arr [0:DAYS-1];
    reg [COORD_WIDTH-1:0] R_arr [0:DAYS-1];
    
    // Flower masks: for each day j, 32-bit vector where bit x = 1 if flower exists
    reg [(1<<COORD_WIDTH)-1:0] flower_mask [0:DAYS-1];
    
    // Compute loop and temporary registers
    reg [DAY_WIDTH-1:0] j;
    reg [COORD_WIDTH-1:0] L_current, R_current;
    reg [COUNT_WIDTH-1:0] temp_count;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;
    localparam [2:0] DONE = 3'd3;
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all state
            state <= IDLE;
            day_counter <= 3'd0;
            new_flowers <= 4'd0;
            done <= 1'b0;
            j <= 3'd0;
            L_current <= 5'd0;
            R_current <= 5'd0;
            temp_count <= 4'd0;
            // Clear storage arrays
            for (integer i = 0; i < DAYS; i = i + 1) begin
                L_arr[i] <= 5'd0;
                R_arr[i] <= 5'd0;
                flower_mask[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && day_counter < DAYS) begin
                        // Capture inputs and prepare for computation
                        L_current <= L_in;
                        R_current <= R_in;
                        j <= 3'd0;
                        temp_count <= 4'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Process one previous plant per clock cycle
                    if (j < day_counter) begin
                        // Check left stem intersection with plant j
                        if (L_current > L_arr[j] && L_current < R_arr[j]) begin
                            if (!flower_mask[j][L_current]) begin
                                temp_count <= temp_count + 1;
                                flower_mask[j][L_current] <= 1'b1;
                            end
                        end
                        
                        // Check right stem intersection with plant j
                        if (R_current > L_arr[j] && R_current < R_arr[j]) begin
                            if (!flower_mask[j][R_current]) begin
                                temp_count <= temp_count + 1;
                                flower_mask[j][R_current] <= 1'b1;
                            end
                        end
                        
                        j <= j + 1;
                    end else begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    // Present result and store current plant
                    new_flowers <= temp_count;
                    L_arr[day_counter] <= L_current;
                    R_arr[day_counter] <= R_current;
                    day_counter <= day_counter + 1;
                    done <= 1'b1;
                    state <= DONE;
                end
                
                DONE: begin
                    // Wait for start to deassert before returning to IDLE
                    if (!start) begin
                        done <= 1'b0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule