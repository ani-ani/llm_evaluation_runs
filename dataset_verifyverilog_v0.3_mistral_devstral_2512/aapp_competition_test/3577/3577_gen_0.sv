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
    
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    localparam [1:0] DONE = 2'd3;
    
    // Internal state
    reg [1:0] state;
    reg [DAY_WIDTH-1:0] day_counter;
    reg [DAY_WIDTH-1:0] j;
    reg [COORD_WIDTH-1:0] L_current;
    reg [COORD_WIDTH-1:0] R_current;
    reg [COUNT_WIDTH-1:0] temp_count;
    
    // Storage for previous plants
    reg [COORD_WIDTH-1:0] L_arr [0:DAYS-1];
    reg [COORD_WIDTH-1:0] R_arr [0:DAYS-1];
    reg [(1<<COORD_WIDTH)-1:0] flower_mask [0:DAYS-1];
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            day_counter <= 0;
            new_flowers <= 0;
            done <= 0;
            j <= 0;
            L_current <= 0;
            R_current <= 0;
            temp_count <= 0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < DAYS; i = i + 1) begin
                L_arr[i] <= 0;
                R_arr[i] <= 0;
                flower_mask[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && day_counter < DAYS) begin
                        L_current <= L_in;
                        R_current <= R_in;
                        j <= 0;
                        temp_count <= 0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    if (j < day_counter) begin
                        // Check left stem intersection
                        if (L_current > L_arr[j] && L_current < R_arr[j]) begin
                            if (!flower_mask[j][L_current]) begin
                                temp_count <= temp_count + 1;
                                flower_mask[j][L_current] <= 1;
                            end
                        end
                        
                        // Check right stem intersection
                        if (R_current > L_arr[j] && R_current < R_arr[j]) begin
                            if (!flower_mask[j][R_current]) begin
                                temp_count <= temp_count + 1;
                                flower_mask[j][R_current] <= 1;
                            end
                        end
                        
                        j <= j + 1;
                    end else begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    new_flowers <= temp_count;
                    L_arr[day_counter] <= L_current;
                    R_arr[day_counter] <= R_current;
                    day_counter <= day_counter + 1;
                    done <= 1'b1;
                    state <= DONE;
                end
                
                DONE: begin
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