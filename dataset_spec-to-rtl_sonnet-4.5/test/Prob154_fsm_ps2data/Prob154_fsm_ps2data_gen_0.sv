module TopModule(
    input clk,
    input reset,
    input [7:0] in,
    output reg [23:0] out_bytes,
    output reg done
);

    // State encoding
    typedef enum reg [1:0] {
        IDLE = 2'b00,
        BYTE1 = 2'b01,
        BYTE2 = 2'b10,
        BYTE3 = 2'b11
    } state_t;

    state_t current_state, next_state;
    reg [7:0] byte1, byte2, byte3;
    reg [7:0] next_byte1, next_byte2, next_byte3;

    // State register
    always @(posedge clk) begin
        if (reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (in[3] == 1'b1) begin
                    next_state = BYTE1;
                end
            end
            BYTE1: begin
                next_state = BYTE2;
            end
            BYTE2: begin
                next_state = BYTE3;
            end
            BYTE3: begin
                if (in[3] == 1'b1) begin
                    next_state = BYTE1;
                end else begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Datapath registers
    always @(posedge clk) begin
        if (reset) begin
            byte1 <= 8'b0;
            byte2 <= 8'b0;
            byte3 <= 8'b0;
        end else begin
            byte1 <= next_byte1;
            byte2 <= next_byte2;
            byte3 <= next_byte3;
        end
    end

    // Datapath logic
    always @(*) begin
        next_byte1 = byte1;
        next_byte2 = byte2;
        next_byte3 = byte3;
        
        case (current_state)
            IDLE: begin
                if (in[3] == 1'b1) begin
                    next_byte1 = in;
                end
            end
            BYTE1: begin
                next_byte2 = in;
            end
            BYTE2: begin
                next_byte3 = in;
            end
            BYTE3: begin
                if (in[3] == 1'b1) begin
                    next_byte1 = in;
                end
            end
        endcase
    end

    // Output logic
    always @(*) begin
        done = (current_state == BYTE3);
        out_bytes = {byte1, byte2, byte3};
    end

endmodule