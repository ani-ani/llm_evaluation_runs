module IntegerFilter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] arr [0:7],
    output reg [255:0] result,
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] FILTER  = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Control signals
    reg [2:0] index;
    reg [3:0] output_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 256'd0;
            count <= 4'd0;
            done <= 1'b0;
            index <= 3'd0;
            output_index <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FILTER;
                end
            end
            
            FILTER: begin
                if (index == 3'd7) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                FILTER: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current element is integer (type_bit = 0)
                    if (arr[index][15] == 1'b0) begin
                        // Pack into result array
                        result[(output_index * 16) + 15 : output_index * 16] <= arr[index];
                        output_index <= output_index + 4'd1;
                    end
                    
                    // Move to next element
                    index <= index + 3'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    count <= output_index;
                    index <= 3'd0;
                    output_index <= 4'd0;
                end
                
                default: begin
                    done <= 1'b0;
                    count <= 4'd0;
                    result <= 256'd0;
                    index <= 3'd0;
                    output_index <= 4'd0;
                end
            endcase
        end
    end

endmodule