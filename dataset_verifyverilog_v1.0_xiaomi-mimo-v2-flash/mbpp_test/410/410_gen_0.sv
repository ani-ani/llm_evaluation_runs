module FindMinInteger (
    input wire clk,
    input wire rst_n,
    input wire [7:0] data [0:7],
    input wire [7:0] tags,
    output reg [7:0] min_val,
    output reg valid
);

    // State definitions for sequential implementation
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN = 3'd1;
    localparam [2:0] DONE = 3'd2;

    reg [2:0] state, next_state;
    reg [2:0] index;           // Current index (0-7)
    reg [7:0] current_min;     // Temporary min register
    reg found_int;             // Flag to track if any integer found
    reg [7:0] min_val_reg;     // Output register
    reg valid_reg;             // Output register

    // Combinational logic for next state and outputs
    always @(*) begin
        // Default next state
        next_state = state;
        
        case (state)
            IDLE: begin
                if (!rst_n) begin
                    next_state = IDLE;
                end else begin
                    next_state = SCAN;
                end
            end
            
            SCAN: begin
                if (index == 3'd7) begin
                    next_state = DONE;
                end else begin
                    next_state = SCAN;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            index <= 3'd0;
            current_min <= 8'd0;
            found_int <= 1'b0;
            min_val_reg <= 8'd0;
            valid_reg <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    // Initialize for new scan
                    index <= 3'd0;
                    current_min <= 8'd0;
                    found_int <= 1'b0;
                    valid_reg <= 1'b0;
                end
                
                SCAN: begin
                    // Check current element
                    if (tags[index]) begin
                        // This is an integer
                        if (!found_int) begin
                            // First integer found
                            current_min <= data[index];
                            found_int <= 1'b1;
                        end else begin
                            // Compare with current min
                            if (data[index] < current_min) begin
                                current_min <= data[index];
                            end
                        end
                    end
                    
                    // Increment index
                    index <= index + 3'd1;
                end
                
                DONE: begin
                    // Transfer results to output
                    min_val_reg <= current_min;
                    valid_reg <= found_int;
                end
                
                default: begin
                    state <= IDLE;
                    index <= 3'd0;
                    current_min <= 8'd0;
                    found_int <= 1'b0;
                    min_val_reg <= 8'd0;
                    valid_reg <= 1'b0;
                end
            endcase
        end
    end

    // Assign outputs
    assign min_val = min_val_reg;
    assign valid = valid_reg;

endmodule