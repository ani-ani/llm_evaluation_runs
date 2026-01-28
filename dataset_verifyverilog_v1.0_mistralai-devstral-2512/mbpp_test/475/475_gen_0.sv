module SortModule(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] key_in [0:7],
    input wire signed [15:0] value_in [0:7],
    input wire valid_in [0:7],
    output reg [31:0] key_out [0:7],
    output reg signed [15:0] value_out [0:7],
    output reg valid_out [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Internal buffers
    reg [31:0] key_buf [0:7];
    reg signed [15:0] value_buf [0:7];
    reg valid_buf [0:7];
    
    // Sorting variables
    reg [2:0] i_reg, j_reg;
    reg signed [15:0] temp_value;
    reg [31:0] temp_key;
    reg temp_valid;
    
    // Cycle counter
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all outputs
            for (integer i = 0; i < 8; i = i + 1) begin
                key_out[i] <= 32'd0;
                value_out[i] <= 16'd0;
                valid_out[i] <= 1'b0;
            end
            
            // Initialize internal buffers
            for (integer i = 0; i < 8; i = i + 1) begin
                key_buf[i] <= 32'd0;
                value_buf[i] <= 16'd0;
                valid_buf[i] <= 1'b0;
            end
            
            i_reg <= 3'd0;
            j_reg <= 3'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    // Load all inputs into buffers
                    for (integer i = 0; i < 8; i = i + 1) begin
                        key_buf[i] <= key_in[i];
                        value_buf[i] <= value_in[i];
                        valid_buf[i] <= valid_in[i];
                    end
                    
                    // Initialize sorting indices
                    i_reg <= 3'd1;
                    j_reg <= 3'd0;
                    next_state <= SORT;
                end
                
                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Insertion sort algorithm
                    if (i_reg < 8) begin
                        // Store current element
                        temp_value <= value_buf[i_reg];
                        temp_key <= key_buf[i_reg];
                        temp_valid <= valid_buf[i_reg];
                        j_reg <= i_reg - 1;
                        
                        // Shift elements greater than current
                        if (j_reg >= 0 && valid_buf[j_reg] && temp_valid && 
                            value_buf[j_reg] < temp_value) begin
                            value_buf[j_reg + 1] <= value_buf[j_reg];
                            key_buf[j_reg + 1] <= key_buf[j_reg];
                            valid_buf[j_reg + 1] <= valid_buf[j_reg];
                            j_reg <= j_reg - 1;
                        end else if (j_reg >= 0 && !valid_buf[j_reg]) begin
                            j_reg <= j_reg - 1;
                        end else begin
                            // Insert current element
                            value_buf[j_reg + 1] <= temp_value;
                            key_buf[j_reg + 1] <= temp_key;
                            valid_buf[j_reg + 1] <= temp_valid;
                            i_reg <= i_reg + 1;
                        end
                    end else begin
                        // Sorting complete
                        next_state <= DONE_STATE;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    // Output sorted results
                    for (integer i = 0; i < 8; i = i + 1) begin
                        key_out[i] <= key_buf[i];
                        value_out[i] <= value_buf[i];
                        valid_out[i] <= valid_buf[i];
                    end
                    
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule