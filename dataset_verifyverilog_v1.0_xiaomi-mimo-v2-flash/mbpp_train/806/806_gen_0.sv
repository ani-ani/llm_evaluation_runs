module max_run_length (
    input clk,
    input rst_n,
    input [7:0] str [15:0],
    input start,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] index;           // 0-15
    reg [3:0] current_run;
    reg [3:0] max_run;
    reg [3:0] result_reg;
    reg done_reg;

    // Combinational signals
    wire [7:0] current_char;
    wire is_uppercase;
    wire [3:0] next_current_run;
    wire [3:0] next_max_run;

    assign current_char = str[index];
    assign is_uppercase = (current_char >= 8'h41) && (current_char <= 8'h5A);
    
    // Next current_run: increment if uppercase, else reset to 0
    assign next_current_run = is_uppercase ? (current_run + 4'd1) : 4'd0;
    
    // Next max_run: take max of current_run and max_run
    assign next_max_run = (current_run > max_run) ? current_run : max_run;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (index == 4'd15)  // Last character (0-15)
                    next_state = DONE_STATE;
                else
                    next_state = PROCESSING;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            current_run <= 4'd0;
            max_run <= 4'd0;
            result_reg <= 4'd0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    if (start) begin
                        index <= 4'd0;
                        current_run <= 4'd0;
                        max_run <= 4'd0;
                    end
                end
                
                PROCESSING: begin
                    // Update current_run based on character
                    current_run <= next_current_run;
                    
                    // Update max_run if current_run is greater
                    if (current_run > max_run)
                        max_run <= current_run;
                    
                    // Increment index
                    if (index < 4'd15)
                        index <= index + 4'd1;
                end
                
                DONE_STATE: begin
                    // Final update: compare current_run with max_run
                    if (current_run > max_run) begin
                        result_reg <= current_run;
                    end else begin
                        result_reg <= max_run;
                    end
                    done_reg <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Assign outputs
    always @(*) begin
        result = result_reg;
        done = done_reg;
    end

endmodule