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

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] count;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                out_chars[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                count <= 4'd0;
                if (start) begin
                    next_state = PROCESS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESS: begin
                if (count < str_len && count < 16) begin
                    out_chars[count] = char_in;
                end
                
                if (count < 15 && count < str_len - 1) begin
                    count = count + 1;
                    next_state = PROCESS;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                valid <= 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule