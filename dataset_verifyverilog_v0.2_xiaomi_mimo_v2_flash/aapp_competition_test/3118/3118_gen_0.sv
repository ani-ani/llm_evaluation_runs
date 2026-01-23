module shuffling_game(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0][7:0] alice_perm,
    input [7:0][7:0] bob_perm,
    output reg [15:0] result,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam RUN = 2'b01;
    localparam DONE = 2'b10;
    localparam HUGE = 2'b11;

    reg [1:0] state;
    reg [15:0] step_count;
    reg [7:0] deck [0:7];
    wire [7:0] next_deck [0:7];
    wire is_identity_next;
    wire [15:0] next_step;
    integer i;

    // Combinational logic for next_deck
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            if (step_count[0] == 0)
                next_deck[i] = deck[alice_perm[i]];
            else
                next_deck[i] = deck[bob_perm[i]];
        end
    end

    // Combinational logic for is_identity_next
    always @(*) begin
        is_identity_next = 1'b1;
        for (i = 0; i < n; i = i + 1) begin
            if (next_deck[i] != i[7:0])
                is_identity_next = 1'b0;
        end
    end

    // Combinational logic for next_step
    always @(*) begin
        next_step = step_count + 1;
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            step_count <= 0;
            done <= 0;
            result <= 0;
            for (i = 0; i < 8; i = i + 1) deck[i] <= i[7:0];
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        for (int k = 0; k < 8; k = k + 1) deck[k] <= k[7:0];
                        step_count <= 0;
                        state <= RUN;
                    end
                end
                RUN: begin
                    if (start) begin
                        state <= IDLE;
                        done <= 0;
                    end else if (next_step > 128) begin
                        state <= HUGE;
                        result <= 16'hFFFF;
                        done <= 1;
                    end else if (is_identity_next) begin
                        state <= DONE;
                        result <= next_step;
                        done <= 1;
                    end else begin
                        deck <= next_deck;
                        step_count <= next_step;
                    end
                end
                DONE: begin
                    if (start) begin
                        for (int k = 0; k < 8; k = k + 1) deck[k] <= k[7:0];
                        step_count <= 0;
                        done <= 0;
                        state <= RUN;
                    end
                end
                HUGE: begin
                    if (start) begin
                        for (int k = 0; k < 8; k = k + 1) deck[k] <= k[7:0];
                        step_count <= 0;
                        done <= 0;
                        state <= RUN;
                    end
                end
            endcase
        end
    end
endmodule