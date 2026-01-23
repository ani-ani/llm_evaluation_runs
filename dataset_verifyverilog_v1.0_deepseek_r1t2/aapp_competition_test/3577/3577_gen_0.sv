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
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    localparam [1:0] DONE_ST = 2'd3;
    
    reg [1:0] state, next_state;
    reg [DAY_WIDTH-1:0] day_counter;
    reg [COORD_WIDTH-1:0] L_reg, R_reg;
    
    // Plant storage arrays
    reg [COORD_WIDTH-1:0] L_arr [0:DAYS-1];
    reg [COORD_WIDTH-1:0] R_arr [0:DAYS-1];
    
    // Flower mask storage
    reg [(1<<COORD_WIDTH)-1:0] flower_mask [0:DAYS-1];
    
    // Computation registers
    reg [DAY_WIDTH-1:0] j;
    reg [COUNT_WIDTH-1:0] temp_count;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            day_counter <= {DAY_WIDTH{1'b0}};
            new_flowers <= {COUNT_WIDTH{1'b0}};
            done <= 1'b0;
            L_reg <= {COORD_WIDTH{1'b0}};
            R_reg <= {COORD_WIDTH{1'b0}};
            j <= {DAY_WIDTH{1'b0}};
            temp_count <= {COUNT_WIDTH{1'b0}};
            
            // Reset arrays
            for (i = 0; i < DAYS; i = i + 1) begin
                L_arr[i] <= {COORD_WIDTH{1'b0}};
                R_arr[i] <= {COORD_WIDTH{1'b0}};
                flower_mask[i] <= {(1<<COORD_WIDTH){1'b0}};
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && (day_counter < DAYS)) begin
                        L_reg <= L_in;
                        R_reg <= R_in;
                        j <= {DAY_WIDTH{1'b0}};
                        temp_count <= {COUNT_WIDTH{1'b0}};
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    if (j < day_counter) begin
                        // Check left stem
                        if ((L_reg > L_arr[j]) && (L_reg < R_arr[j])) begin
                            if (!flower_mask[j][L_reg]) begin
                                temp_count <= temp_count + 4'd1;
                                flower_mask[j][L_reg] <= 1'b1;
                            end
                        end
                        
                        // Check right stem
                        if ((R_reg > L_arr[j]) && (R_reg < R_arr[j])) begin
                            if (!flower_mask[j][R_reg]) begin
                                temp_count <= temp_count + 4'd1;
                                flower_mask[j][R_reg] <= 1'b1;
                            end
                        end
                        
                        j <= j + 3'd1;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    new_flowers <= temp_count;
                    L_arr[day_counter] <= L_reg;
                    R_arr[day_counter] <= R_reg;
                    day_counter <= day_counter + 3'd1;
                    done <= 1'b1;
                    next_state <= DONE_ST;
                end
                
                DONE_ST: begin
                    if (!start) begin
                        next_state <= IDLE;
                    end else begin
                        next_state <= DONE_ST;
                    end
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule