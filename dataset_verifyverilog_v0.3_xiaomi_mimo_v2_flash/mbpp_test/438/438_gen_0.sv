module count_bidirectional #(
    parameter MAX_PAIRS = 8,
    parameter DATA_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] arr_a [0:MAX_PAIRS-1],
    input wire [DATA_WIDTH-1:0] arr_b [0:MAX_PAIRS-1],
    input wire [3:0] valid_pairs,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] COMPARE     = 3'd1;
    localparam [2:0] INCREMENT_J = 3'd2;
    localparam [2:0] INCREMENT_I = 3'd3;
    localparam [2:0] COMPLETE    = 3'd4;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] i;
    reg [3:0] j;
    reg [7:0] count;
    reg [7:0] next_count;
    reg [7:0] next_result;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            count <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            i <= i;
            j <= j;
            count <= next_count;
            result <= next_result;
            
            // Update loop counters based on state
            if (state == IDLE && start && valid_pairs > 4'd1) begin
                i <= 4'd0;
                j <= 4'd1;
                count <= 8'd0;
            end else if (state == INCREMENT_J) begin
                j <= j + 4'd1;
            end else if (state == INCREMENT_I) begin
                i <= i + 4'd1;
                j <= i + 4'd2;
            end
        end
    end
    
    always @(*) begin
        // Default assignments
        next_state = state;
        next_count = count;
        next_result = result;
        
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start && valid_pairs > 4'd1) begin
                    next_state = COMPARE;
                end else if (start) begin
                    // Single pair or zero pairs
                    next_result = 8'd0;
                    done = 1'b1;
                    next_state = IDLE;
                end
            end
            
            COMPARE: begin
                // Check bidirectional condition
                if (i < valid_pairs && j < valid_pairs) begin
                    if (arr_a[i] == arr_b[j] && arr_b[i] == arr_a[j]) begin
                        next_count = count + 8'd1;
                    end
                end
                next_state = INCREMENT_J;
            end
            
            INCREMENT_J: begin
                if (j < valid_pairs - 4'd1) begin
                    next_state = COMPARE;
                end else begin
                    // End of inner loop
                    if (i < valid_pairs - 4'd2) begin
                        next_state = INCREMENT_I;
                    end else begin
                        next_result = count;
                        done = 1'b1;
                        next_state = COMPLETE;
                    end
                end
            end
            
            INCREMENT_I: begin
                next_state = COMPARE;
            end
            
            COMPLETE: begin
                if (!start) begin
                    done = 1'b0;
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule