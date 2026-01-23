module vowels_count(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [3:0] valid_len,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Registers for state and counters
    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [3:0] index;
    reg [3:0] count;

    // Combinational logic for char lookup based on current index
    reg [7:0] current_char;
    always @(*) begin
        case (index)
            4'd0: current_char = char_0;
            4'd1: current_char = char_1;
            4'd2: current_char = char_2;
            4'd3: current_char = char_3;
            4'd4: current_char = char_4;
            4'd5: current_char = char_5;
            4'd6: current_char = char_6;
            4'd7: current_char = char_7;
            default: current_char = 8'h00;
        endcase
    end

    // Combinational logic for vowel detection
    wire is_vowel;
    wire is_last;
    wire is_y;
    wire is_vowel_or_y_last;

    // ASCII values for vowels
    // A=65 (0x41), a=97 (0x61)
    // E=69 (0x45), e=101 (0x65)
    // I=73 (0x49), i=105 (0x69)
    // O=79 (0x4F), o=111 (0x6F)
    // U=85 (0x55), u=117 (0x75)
    // Y=89 (0x59), y=121 (0x79)

    assign is_vowel = (
        (current_char == 8'h41) || (current_char == 8'h61) || // A or a
        (current_char == 8'h45) || (current_char == 8'h65) || // E or e
        (current_char == 8'h49) || (current_char == 8'h69) || // I or i
        (current_char == 8'h4F) || (current_char == 8'h6F) || // O or o
        (current_char == 8'h55) || (current_char == 8'h75)    // U or u
    );

    assign is_last = (index == valid_len - 1);
    assign is_y = ((current_char == 8'h59) || (current_char == 8'h79)); // Y or y

    // Check if character counts as a vowel (standard vowel OR y at last position)
    assign is_vowel_or_y_last = is_vowel || (is_last && is_y);

    // Sequential logic for State Transition, Index, and Result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            index <= 4'b0;
            result <= 4'b0;
            done <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_state <= PROCESSING;
                        index <= 4'b0;
                        result <= 4'b0;
                    end
                end

                PROCESSING: begin
                    // Check current character
                    if (is_vowel_or_y_last) begin
                        result <= result + 1;
                    end

                    // Move to next character or finish
                    if (index < valid_len - 1) begin
                        index <= index + 1;
                    end else begin
                        // We processed the last character (index valid_len-1)
                        // Transition to DONE state on next cycle
                        current_state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Wait for reset or start signal (implicit transition to IDLE handled by start check in IDLE or reset)
                    // Ideally, stay in DONE until reset or new start. 
                    // The description "On start, process..." implies we react to start.
                    // To allow restarting without reset, we transition to IDLE after setting done high,
                    // or simply rely on the user to deassert start. 
                    // Let's check for start low to return to IDLE logic or simply stay until reset.
                    // Standard practice for control FSMs: 
                    // We will stay DONE until start is deasserted, then go to IDLE, 
                    // OR wait for start asserted in DONE to go to PROCESSING.
                    
                    // Let's make it robust: 
                    // If start is low, go to IDLE (ready for next start).
                    // If start is high, stay in DONE (or maybe restart if we wanted continuous mode, 
                    // but description implies single shot: "On start, process"). 
                    // Let's assume single shot: 
                    // Transition to IDLE once start is deasserted.
                    if (!start) begin
                        current_state <= IDLE;
                        done <= 1'b0; // Deassert done when returning to idle
                    end
                end

                default: current_state <= IDLE;
            endcase
        end
    end

endmodule
