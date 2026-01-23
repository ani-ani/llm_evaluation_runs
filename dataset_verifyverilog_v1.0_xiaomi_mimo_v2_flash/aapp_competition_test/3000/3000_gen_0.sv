module BracketEvaluator(
    input clk,
    input rst_n,
    input start,
    input [3:0] token_count,
    input [9:0] token_0,
    input [9:0] token_1,
    input [9:0] token_2,
    input [9:0] token_3,
    input [9:0] token_4,
    input [9:0] token_5,
    input [9:0] token_6,
    input [9:0] token_7,
    input [9:0] token_8,
    input [9:0] token_9,
    input [9:0] token_10,
    input [9:0] token_11,
    input [9:0] token_12,
    input [9:0] token_13,
    input [9:0] token_14,
    input [9:0] token_15,
    output reg [7:0] result,
    output reg done,
    output reg error
);

    // State machine states
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] FETCH     = 3'd1;
    localparam [2:0] EXEC      = 3'd2;
    localparam [2:0] POP_OP    = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    localparam [2:0] ERROR_OUT = 3'd5;

    // Mode constants
    localparam [0:0] MODE_ADD  = 1'b0;
    localparam [0:0] MODE_MULT = 1'b1;

    // Token type constants
    localparam [1:0] TYPE_NUM  = 2'b00;
    localparam [1:0] TYPE_LP   = 2'b01;
    localparam [1:0] TYPE_RP   = 2'b10;

    // Stack registers (max depth 4)
    reg [7:0] stack_value[0:3];
    reg [0:0] stack_mode[0:3];
    reg [2:0] sp;  // stack pointer (0-4)

    // Current state registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] current_value;
    reg [0:0] current_mode;
    reg [7:0] counter;  // token index
    reg [3:0] proc_count;  // processed token count
    reg [7:0] max_cycles;  // prevent infinite loops
    reg error_flag;
    reg done_flag;

    // Temporary storage for arithmetic
    reg [7:0] temp_result;
    reg [15:0] mult_temp;

    // Current token extraction
    reg [9:0] current_token;
    reg [1:0] token_type;
    reg [7:0] token_value;

    // Integer for loop
    integer i;

    // Token selection logic
    always @(*) begin
        case (counter)
            8'd0:   current_token = token_0;
            8'd1:   current_token = token_1;
            8'd2:   current_token = token_2;
            8'd3:   current_token = token_3;
            8'd4:   current_token = token_4;
            8'd5:   current_token = token_5;
            8'd6:   current_token = token_6;
            8'd7:   current_token = token_7;
            8'd8:   current_token = token_8;
            8'd9:   current_token = token_9;
            8'd10:  current_token = token_10;
            8'd11:  current_token = token_11;
            8'd12:  current_token = token_12;
            8'd13:  current_token = token_13;
            8'd14:  current_token = token_14;
            8'd15:  current_token = token_15;
            default: current_token = 10'd0;
        endcase
        token_type = current_token[9:8];
        token_value = current_token[7:0];
    end

    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) begin
                    if (token_count >= 4'd1 && token_count <= 4'd16) begin
                        next_state = FETCH;
                    end else begin
                        next_state = ERROR_OUT;
                    end
                end else begin
                    next_state = IDLE;
                end
            end

            FETCH: begin
                if (counter < token_count && proc_count < token_count) begin
                    next_state = EXEC;
                end else begin
                    if (sp == 3'd0 && !error_flag) begin
                        next_state = FINISH;
                    end else if (error_flag) begin
                        next_state = ERROR_OUT;
                    end else begin
                        // Stack not empty at end of input
                        next_state = ERROR_OUT;
                    end
                end
            end

            EXEC: begin
                case (token_type)
                    TYPE_NUM: begin
                        next_state = FETCH;
                    end
                    TYPE_LP: begin
                        next_state = FETCH;
                    end
                    TYPE_RP: begin
                        if (sp == 3'd0) begin
                            next_state = ERROR_OUT;
                        end else begin
                            next_state = POP_OP;
                        end
                    end
                    default: begin
                        next_state = ERROR_OUT;
                    end
                endcase
            end

            POP_OP: begin
                next_state = FETCH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            ERROR_OUT: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register and main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_value <= 8'd0;
            current_mode <= MODE_ADD;
            counter <= 8'd0;
            proc_count <= 4'd0;
            sp <= 3'd0;
            max_cycles <= 8'd0;
            error_flag <= 1'b0;
            done_flag <= 1'b0;
            result <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                stack_value[i] <= 8'd0;
                stack_mode[i] <= MODE_ADD;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            error <= 1'b0;
            max_cycles <= max_cycles + 8'd1;

            case (next_state)
                IDLE: begin
                    done_flag <= 1'b0;
                    error_flag <= 1'b0;
                end

                FETCH: begin
                    counter <= counter + 8'd1;
                    proc_count <= proc_count + 4'd1;
                end

                EXEC: begin
                    case (token_type)
                        TYPE_NUM: begin
                            if (current_mode == MODE_ADD) begin
                                current_value <= current_value + token_value;
                            end else begin
                                mult_temp = current_value * token_value;
                                current_value <= mult_temp[7:0];
                            end
                        end

                        TYPE_LP: begin
                            if (sp < 4'd4) begin
                                stack_value[sp] <= current_value;
                                stack_mode[sp] <= current_mode;
                                sp <= sp + 3'd1;
                                current_mode <= ~current_mode;
                                if (current_mode == MODE_ADD) begin
                                    current_value <= 8'd0;
                                end else begin
                                    current_value <= 8'd1;
                                end
                            end else begin
                                error_flag <= 1'b1;
                            end
                        end

                        TYPE_RP: begin
                            // Will be handled in POP_OP state
                        end
                    endcase
                end

                POP_OP: begin
                    sp <= sp - 3'd1;
                    if (stack_mode[sp-3'd1] == MODE_ADD) begin
                        current_value <= current_value + stack_value[sp-3'd1];
                    end else begin
                        mult_temp = current_value * stack_value[sp-3'd1];
                        current_value <= mult_temp[7:0];
                    end
                    current_mode <= stack_mode[sp-3'd1];
                end

                FINISH: begin
                    result <= current_value;
                    done <= 1'b1;
                    done_flag <= 1'b1;
                end

                ERROR_OUT: begin
                    error <= 1'b1;
                    error_flag <= 1'b1;
                end
            endcase

            // Force error if max cycles exceeded
            if (max_cycles >= 8'd32) begin
                state <= ERROR_OUT;
                error_flag <= 1'b1;
            end
        end
    end

endmodule