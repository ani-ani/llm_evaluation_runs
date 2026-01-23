module upper_ctr (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] str_len,
    output reg [7:0] count,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] FINISHED = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg [7:0] next_count;
    reg next_done;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            count <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNTING;
                        index <= 4'd0;
                        count <= 8'd0;
                    end
                end
                
                COUNTING: begin
                    // Check if current character is uppercase (A-Z)
                    if (char_in >= 8'h41 && char_in <= 8'h5A) begin
                        count <= count + 8'd1;
                    end
                    
                    // Move to next character
                    if (index < str_len - 4'd1) begin
                        index <= index + 4'd1;
                    end else begin
                        state <= FINISHED;
                        done <= 1'b1;
                    end
                end
                
                FINISHED: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                    index <= 4'd0;
                    count <= 8'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule