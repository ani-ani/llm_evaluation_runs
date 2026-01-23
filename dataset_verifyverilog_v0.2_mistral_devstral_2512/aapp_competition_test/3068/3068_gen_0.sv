module black_vienna_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] num_investigations,
    input wire [7:0] inv_suspect1,
    input wire [7:0] inv_suspect2,
    input wire [7:0] inv_player,
    input wire [7:0] inv_reply,
    input wire inv_valid,
    output reg [15:0] solution_count,
    output reg done,
    output reg error
);

    localparam IDLE = 3'b000;
    localparam LOAD_INV = 3'b001;
    localparam CHECK_CIRCLE = 3'b010;
    localparam VERIFY_INV = 3'b011;
    localparam COUNT_SOLUTION = 3'b100;
    localparam FINISHED = 3'b101;

    localparam SUSPECT_A = 8'h41;
    localparam SUSPECT_B = 8'h42;
    localparam SUSPECT_C = 8'h43;
    localparam SUSPECT_D = 8'h44;

    reg [2:0] current_state;
    reg [2:0] next_state;

    reg [1:0] c0, c1, c2;
    reg [1:0] c0_next, c1_next, c2_next;

    reg [31:0] inv_mem [0:3];
    reg [5:0] inv_load_idx;
    reg [5:0] inv_check_idx;

    reg is_valid_sol;
    reg [1:0] sus1_decoded;
    reg [1:0] sus2_decoded;
    reg [1:0] player_decoded;
    reg [1:0] reply_decoded;
    reg [1:0] count;

    always @(*) begin
        error = 1'b0;
        sus1_decoded = 2'b00;
        sus2_decoded = 2'b00;
        
        case (inv_suspect1)
            SUSPECT_A: sus1_decoded = 2'd0;
            SUSPECT_B: sus1_decoded = 2'd1;
            SUSPECT_C: sus1_decoded = 2'd2;
            SUSPECT_D: sus1_decoded = 2'd3;
            default: error = 1'b1;
        endcase

        case (inv_suspect2)
            SUSPECT_A: sus2_decoded = 2'd0;
            SUSPECT_B: sus2_decoded = 2'd1;
            SUSPECT_C: sus2_decoded = 2'd2;
            SUSPECT_D: sus2_decoded = 2'd3;
            default: error = 1'b1;
        endcase
        
        if (inv_suspect1 == inv_suspect2) error = 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            solution_count <= 16'd0;
            done <= 1'b0;
            inv_load_idx <= 6'd0;
            inv_check_idx <= 6'd0;
            {c0, c1, c2} <= 6'd0;
        end else begin
            current_state <= next_state;
            
            if (current_state == IDLE && start) begin
                solution_count <= 16'd0;
                done <= 1'b0;
                inv_load_idx <= 6'd0;
                inv_check_idx <= 6'd0;
                c0 <= 2'd0;
                c1 <= 2'd1;
                c2 <= 2'd2;
            end
            
            if (current_state == LOAD_INV && inv_valid) begin
                inv_mem[inv_load_idx] <= {sus1_decoded, sus2_decoded, inv_player[0], inv_reply[1:0], 1'b1};
                inv_load_idx <= inv_load_idx + 1'b1;
            end

            if (current_state == COUNT_SOLUTION) begin
                solution_count <= solution_count + 1'b1;
            end

            if (current_state == CHECK_CIRCLE) begin
                if (c2 < 2'd3) begin
                    c2 <= c2 + 1'b1;
                end else begin
                    c2 <= c2 + 1'b1;
                    if (c1 < c2 - 1'b1) begin
                        c1 <= c1 + 1'b1;
                        c2 <= c1 + 2'd2;
                    end else begin
                        c1 <= c0 + 1'b1;
                        c2 <= c0 + 2'd2;
                        c0 <= c0 + 1'b1;
                    end
                end
            end
        end
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_INV;
            end
            LOAD_INV: begin
                if (error) next_state = FINISHED;
                else if (inv_valid) begin
                    if (inv_load_idx + 1'b1 >= num_investigations || inv_load_idx >= 3'd4)
                        next_state = CHECK_CIRCLE;
                    else
                        next_state = LOAD_INV;
                end
            end
            CHECK_CIRCLE: begin
                if (c0 >= 2'd3) next_state = FINISHED;
                else next_state = VERIFY_INV;
            end
            VERIFY_INV: begin
                if (inv_check_idx >= num_investigations || inv_check_idx >= 3'd4) begin
                    next_state = COUNT_SOLUTION;
                end else if (inv_mem[inv_check_idx][0] == 1'b0) begin
                    next_state = COUNT_SOLUTION;
                end else begin
                    next_state = VERIFY_INV;
                end
            end
            COUNT_SOLUTION: begin
                next_state = CHECK_CIRCLE;
            end
            FINISHED: begin
                next_state = FINISHED;
            end
            default: next_state = IDLE;
        endcase
    end

    reg verify_fail;
    always @(*) begin
        verify_fail = 1'b0;
        
        if (current_state == VERIFY_INV) begin
            reg [31:0] inv_data = inv_mem[inv_check_idx];
            if (inv_check_idx < num_investigations && inv_check_idx < 4 && inv_data[0]) begin
                reg [1:0] s1 = inv_data[31:30];
                reg [1:0] s2 = inv_data[29:28];
                reg p = inv_data[27];
                reg [1:0] r = inv_data[26:25];
                
                reg [1:0] k;
                k = 0;
                if ((s1 == c0 || s1 == c1 || s1 == c2)) k = k + 1;
                if ((s2 == c0 || s2 == c1 || s2 == c2)) k = k + 1;
                
                if (k == 2'd2 && r != 2'd0) verify_fail = 1'b1;
                else if (k == 2'd1 && r > 2'd1) verify_fail = 1'b1;
            end
        end
    end

    always @(*) begin
        if (current_state == VERIFY_INV) begin
            if (verify_fail) begin
                next_state = CHECK_CIRCLE;
            end else begin
                if (inv_check_idx + 1'b1 >= num_investigations || inv_check_idx >= 3'd4)
                    next_state = COUNT_SOLUTION;
                else
                    next_state = VERIFY_INV;
            end
        end
    end
    
    always @(posedge clk) begin
        if (current_state == VERIFY_INV && !verify_fail) begin
            inv_check_idx <= inv_check_idx + 1'b1;
        end else if (current_state == CHECK_CIRCLE) begin
            inv_check_idx <= 6'd0;
        end
    end

endmodule