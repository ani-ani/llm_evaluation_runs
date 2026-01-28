module MaxDamageCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] jiro_pos,
    input wire [15:0][12:0] jiro_str,
    input wire [15:0][12:0] ciel_str,
    input wire [3:0] n,
    input wire [3:0] m,
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [4:0] IDLE = 5'd0;
    localparam [4:0] PARSE = 5'd1;
    localparam [4:0] SORT_DEF = 5'd2;
    localparam [4:0] SORT_ATK = 5'd3;
    localparam [4:0] SORT_CIEL = 5'd4;
    localparam [4:0] STRAT1_DEF = 5'd5;
    localparam [4:0] STRAT1_ATK = 5'd6;
    localparam [4:0] STRAT1_DIR = 5'd7;
    localparam [4:0] SORT_ATK2 = 5'd8;
    localparam [4:0] SORT_CIEL2 = 5'd9;
    localparam [4:0] STRAT2 = 5'd10;
    localparam [4:0] RESULT = 5'd11;

    reg [4:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Internal registers for Jiro's cards
    reg [12:0] def_str [0:15];
    reg [12:0] atk_str [0:15];
    reg [3:0] def_count;
    reg [3:0] atk_count;

    // Internal registers for Ciel's cards
    reg [12:0] ciel_sorted [0:15];
    reg [12:0] ciel_sorted2 [0:15];

    // Strategy 1 registers
    reg [23:0] strat1_damage;
    reg [23:0] strat1_dir_damage;
    reg [3:0] ciel_used;
    reg [3:0] ciel_used_atk;

    // Strategy 2 registers
    reg [23:0] strat2_damage;

    // Parsing state
    reg [3:0] parse_idx;

    // Sorting state
    reg [3:0] sort_i;
    reg [3:0] sort_j;
    reg [3:0] sort_k;

    // Strategy 1 state
    reg [3:0] def_idx;
    reg [3:0] atk_idx;
    reg [3:0] ciel_idx;

    // Strategy 2 state
    reg [3:0] ciel_idx2;
    reg [3:0] atk_idx2;

    // Temporary registers
    reg [12:0] temp;
    reg [23:0] temp_damage;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize all internal registers
            def_count <= 4'd0;
            atk_count <= 4'd0;
            parse_idx <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            sort_k <= 4'd0;
            def_idx <= 4'd0;
            atk_idx <= 4'd0;
            ciel_idx <= 4'd0;
            ciel_idx2 <= 4'd0;
            atk_idx2 <= 4'd0;
            ciel_used <= 4'd0;
            ciel_used_atk <= 4'd0;
            strat1_damage <= 24'd0;
            strat1_dir_damage <= 24'd0;
            strat2_damage <= 24'd0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                def_str[i] <= 13'd0;
                atk_str[i] <= 13'd0;
                ciel_sorted[i] <= 13'd0;
                ciel_sorted2[i] <= 13'd0;
            end
        end else begin
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b0;
            end

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PARSE;
                        parse_idx <= 4'd0;
                        def_count <= 4'd0;
                        atk_count <= 4'd0;
                    end
                end

                PARSE: begin
                    if (parse_idx < n) begin
                        if (jiro_pos[parse_idx]) begin
                            atk_str[atk_count] <= jiro_str[parse_idx];
                            atk_count <= atk_count + 4'd1;
                        end else begin
                            def_str[def_count] <= jiro_str[parse_idx];
                            def_count <= def_count + 4'd1;
                        end
                        parse_idx <= parse_idx + 4'd1;
                    end else begin
                        state <= SORT_DEF;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                    end
                end

                SORT_DEF: begin
                    if (sort_i < def_count - 4'd1) begin
                        if (sort_j < def_count - sort_i - 4'd1) begin
                            if (def_str[sort_j] > def_str[sort_j + 4'd1]) begin
                                temp <= def_str[sort_j];
                                def_str[sort_j] <= def_str[sort_j + 4'd1];
                                def_str[sort_j + 4'd1] <= temp;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        state <= SORT_ATK;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                    end
                end

                SORT_ATK: begin
                    if (sort_i < atk_count - 4'd1) begin
                        if (sort_j < atk_count - sort_i - 4'd1) begin
                            if (atk_str[sort_j] > atk_str[sort_j + 4'd1]) begin
                                temp <= atk_str[sort_j];
                                atk_str[sort_j] <= atk_str[sort_j + 4'd1];
                                atk_str[sort_j + 4'd1] <= temp;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        state <= SORT_CIEL;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        for (sort_k = 0; sort_k < m; sort_k = sort_k + 1) begin
                            ciel_sorted[sort_k] <= ciel_str[sort_k];
                        end
                    end
                end

                SORT_CIEL: begin
                    if (sort_i < m - 4'd1) begin
                        if (sort_j < m - sort_i - 4'd1) begin
                            if (ciel_sorted[sort_j] > ciel_sorted[sort_j + 4'd1]) begin
                                temp <= ciel_sorted[sort_j];
                                ciel_sorted[sort_j] <= ciel_sorted[sort_j + 4'd1];
                                ciel_sorted[sort_j + 4'd1] <= temp;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        state <= STRAT1_DEF;
                        def_idx <= 4'd0;
                        ciel_idx <= 4'd0;
                        ciel_used <= 4'd0;
                        strat1_damage <= 24'd0;
                    end
                end

                STRAT1_DEF: begin
                    if (def_idx < def_count) begin
                        if (ciel_idx < m) begin
                            if (ciel_sorted[ciel_idx] > def_str[def_idx]) begin
                                ciel_used <= ciel_used + 4'd1;
                                ciel_idx <= ciel_idx + 4'd1;
                                def_idx <= def_idx + 4'd1;
                            end else begin
                                ciel_idx <= ciel_idx + 4'd1;
                            end
                        end else begin
                            state <= STRAT1_ATK;
                            atk_idx <= 4'd0;
                            ciel_idx <= 4'd0;
                            ciel_used_atk <= 4'd0;
                        end
                    end else begin
                        state <= STRAT1_ATK;
                        atk_idx <= 4'd0;
                        ciel_idx <= 4'd0;
                        ciel_used_atk <= 4'd0;
                    end
                end

                STRAT1_ATK: begin
                    if (atk_idx < atk_count) begin
                        if (ciel_idx < m) begin
                            if (ciel_idx < ciel_used) begin
                                ciel_idx <= ciel_idx + 4'd1;
                            end else if (ciel_sorted[ciel_idx] >= atk_str[atk_idx]) begin
                                temp_damage <= {8'd0, ciel_sorted[ciel_idx]} - {8'd0, atk_str[atk_idx]};
                                strat1_damage <= strat1_damage + temp_damage;
                                ciel_used_atk <= ciel_used_atk + 4'd1;
                                ciel_idx <= ciel_idx + 4'd1;
                                atk_idx <= atk_idx + 4'd1;
                            end else begin
                                ciel_idx <= ciel_idx + 4'd1;
                            end
                        end else begin
                            state <= STRAT1_DIR;
                            ciel_idx <= 4'd0;
                            strat1_dir_damage <= 24'd0;
                        end
                    end else begin
                        state <= STRAT1_DIR;
                        ciel_idx <= 4'd0;
                        strat1_dir_damage <= 24'd0;
                    end
                end

                STRAT1_DIR: begin
                    if (ciel_idx < m) begin
                        if (ciel_idx < ciel_used + ciel_used_atk) begin
                            ciel_idx <= ciel_idx + 4'd1;
                        end else begin
                            strat1_dir_damage <= strat1_dir_damage + {11'd0, ciel_sorted[ciel_idx]};
                            ciel_idx <= ciel_idx + 4'd1;
                        end
                    end else begin
                        state <= SORT_ATK2;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        for (sort_k = 0; sort_k < atk_count; sort_k = sort_k + 1) begin
                            ciel_sorted2[sort_k] <= atk_str[sort_k];
                        end
                    end
                end

                SORT_ATK2: begin
                    if (sort_i < atk_count - 4'd1) begin
                        if (sort_j < atk_count - sort_i - 4'd1) begin
                            if (ciel_sorted2[sort_j] > ciel_sorted2[sort_j + 4'd1]) begin
                                temp <= ciel_sorted2[sort_j];
                                ciel_sorted2[sort_j] <= ciel_sorted2[sort_j + 4'd1];
                                ciel_sorted2[sort_j + 4'd1] <= temp;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        state <= SORT_CIEL2;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        for (sort_k = 0; sort_k < m; sort_k = sort_k + 1) begin
                            ciel_sorted[sort_k] <= ciel_str[sort_k];
                        end
                    end
                end

                SORT_CIEL2: begin
                    if (sort_i < m - 4'd1) begin
                        if (sort_j < m - sort_i - 4'd1) begin
                            if (ciel_sorted[sort_j] < ciel_sorted[sort_j + 4'd1]) begin
                                temp <= ciel_sorted[sort_j];
                                ciel_sorted[sort_j] <= ciel_sorted[sort_j + 4'd1];
                                ciel_sorted[sort_j + 4'd1] <= temp;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        state <= STRAT2;
                        ciel_idx2 <= 4'd0;
                        atk_idx2 <= 4'd0;
                        strat2_damage <= 24'd0;
                    end
                end

                STRAT2: begin
                    if (ciel_idx2 < m && atk_idx2 < atk_count) begin
                        if (ciel_sorted[ciel_idx2] >= ciel_sorted2[atk_idx2]) begin
                            temp_damage <= {8'd0, ciel_sorted[ciel_idx2]} - {8'd0, ciel_sorted2[atk_idx2]};
                            strat2_damage <= strat2_damage + temp_damage;
                            ciel_idx2 <= ciel_idx2 + 4'd1;
                            atk_idx2 <= atk_idx2 + 4'd1;
                        end else begin
                            ciel_idx2 <= ciel_idx2 + 4'd1;
                        end
                    end else begin
                        state <= RESULT;
                    end
                end

                RESULT: begin
                    if (strat1_damage + strat1_dir_damage > strat2_damage) begin
                        result <= strat1_damage + strat1_dir_damage;
                    end else begin
                        result <= strat2_damage;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule