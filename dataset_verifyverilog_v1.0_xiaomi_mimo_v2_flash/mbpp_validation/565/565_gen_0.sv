module char_splitter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] str_len,
    output reg [7:0] out_chars [0:15],
    output reg done,
    output reg valid
);

    // Internal state definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] PROCESS  = 2'd1;
    localparam [1:0] FINISH   = 2'd2;
    
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] count;
    reg [3:0] next_count;
    reg [3:0] max_index;
    
    integer i;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    next_count = 4'd0;
                end else begin
                    next_state = IDLE;
                    next_count = count;
                end
            end
            
            PROCESS: begin
                if (count >= max_index) begin
                    next_state = FINISH;
                    next_count = count;
                end else begin
                    next_state = PROCESS;
                    next_count = count + 4'd1;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
                next_count = 4'd0;
            end
            
            default: begin
                next_state = IDLE;
                next_count = 4'd0;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            max_index <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                out_chars[i] <= 8'h00;
            end
        end else begin
            state <= next_state;
            count <= next_count;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        // Set max index based on string length (1-16)
                        if (str_len == 4'd0) begin
                            max_index <= 4'd15;
                        end else if (str_len > 4'd16) begin
                            max_index <= 4'd15;
                        end else begin
                            max_index <= str_len - 4'd1;
                        end
                    end
                end
                
                PROCESS: begin
                    // Store character at current position
                    if (count < str_len && count < 16) begin
                        out_chars[count] <= char_in;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                end
                
                default: begin
                    // Handle undefined states
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule