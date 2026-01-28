module empty_dict_generator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] length,
    output reg done,
    output reg [31:0] result [0:15]
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] GENERATE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] counter;
    reg [3:0] max_cycles;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = GENERATE;
                else
                    next_state = IDLE;
            end
            
            GENERATE: begin
                if (counter == length - 4'd1)
                    next_state = DONE_STATE;
                else
                    next_state = GENERATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State register and counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            done <= 1'b0;
            max_cycles <= 4'd0;
            
            // Initialize all result entries
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                end
                
                GENERATE: begin
                    done <= 1'b0;
                    result[counter] <= 32'd0;
                    counter <= counter + 4'd1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    counter <= 4'd0;
                end
                
                default: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                end
            endcase
        end
    end

endmodule