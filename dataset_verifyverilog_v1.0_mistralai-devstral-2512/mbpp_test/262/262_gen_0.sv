module array_splitter(
    input clk,
    input rst_n,
    input start,
    input [7:0] in_data [0:15],
    input [3:0] in_len,
    input [3:0] L,
    output reg [7:0] out_first [0:15],
    output reg [7:0] out_second [0:15],
    output reg [3:0] first_len,
    output reg [3:0] second_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [3:0] first_count;
    reg [3:0] second_count;
    reg [3:0] current_len;
    reg [3:0] current_L;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            index <= 4'd0;
            first_count <= 4'd0;
            second_count <= 4'd0;
            current_len <= 4'd0;
            current_L <= 4'd0;
            
            // Initialize output arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                out_first[i] <= 8'd0;
                out_second[i] <= 8'd0;
            end
            first_len <= 4'd0;
            second_len <= 4'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESSING: begin
                if (index == current_len) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESSING;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in reset block
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Capture inputs
                        current_len <= in_len;
                        current_L <= L;
                        index <= 4'd0;
                        first_count <= 4'd0;
                        second_count <= 4'd0;
                        
                        // Initialize output arrays
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            out_first[i] <= 8'd0;
                            out_second[i] <= 8'd0;
                        end
                    end
                end
                
                PROCESSING: begin
                    if (index < current_len) begin
                        if (index < current_L) begin
                            out_first[first_count] <= in_data[index];
                            first_count <= first_count + 4'd1;
                        end else begin
                            out_second[second_count] <= in_data[index];
                            second_count <= second_count + 4'd1;
                        end
                        index <= index + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    first_len <= (current_L < current_len) ? current_L : current_len;
                    second_len <= current_len - first_len;
                end
                
                default: begin
                    // Do nothing
                end
            endcase
        end
    end

endmodule