module settle\_iou (
    input wire clk,
    input wire rst\_n,
    input wire start,
    input wire [3:0] a,
    input wire [3:0] b,
    input wire [7:0] c,
    output reg [7:0] p,
    output reg [7:0] result\_01, result\_02, result\_03, result\_04, result\_05, result\_06, result\_07, result\_08,
    output reg [7:0] result\_10, result\_12, result\_13, result\_14, result\_15, result\_16, result\_17, result\_18,
    output reg [7:0] result\_20, result\_21, result\_23, result\_24, result\_25, result\_26, result\_27, result\_28,
    output reg [7:0] result\_30, result\_31, result\_32, result\_34, result\_35, result\_36, result\_37, result\_38,
    output reg [7:0] result\_40, result\_41, result\_42, result\_43, result\_45, result\_46, result\_47, result\_48,
    output reg [7:0] result\_50, result\_51, result\_52, result\_53, result\_54, result\_56, result\_57, result\_58,
    output reg [7:0] result\_60, result\_61, result\_62, result\_63, result\_64, result\_65, result\_67, result\_68,
    output reg [7:0] result\_70, result\_71, result\_72, result\_73, result\_74, result\_75, result\_76, result\_78,
    output reg [7:0] result\_80, result\_81, result\_82, result\_83, result\_84, result\_85, result\_86, result\_87,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] SETTLE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal state
    reg [2:0] state, next\_state;
    reg [3:0] input\_counter;
    reg [3:0] i\_idx, j\_idx, k\_idx;
    reg [2:0] settle\_iter;
    reg found\_cycle;
    reg [7:0] min\_amount;
    reg [7:0] debt\_matrix [0:7][0:7];
    reg [7:0] temp\_debt\_matrix [0:7][0:7];
    reg [7:0] p\_count;
    integer row, col;

    // Sequential logic
    always @(posedge clk or negedge rst\_n) begin
        if (!rst\_n) begin
            state <= IDLE;
            done <= 1'b0;
            p <= 8'd0;
            input\_counter <= 4'd0;
            i\_idx <= 4'd0;
            j\_idx <= 4'd0;
            k\_idx <= 4'd0;
            settle\_iter <= 3'd0;
            found\_cycle <= 1'b0;
            min\_amount <= 8'd0;
            p\_count <= 8'd0;
            // Initialize debt matrix
            for (row = 0; row < 8; row = row + 1) begin
                for (col = 0; col < 8; col = col + 1) begin
                    debt\_matrix[row][col] <= 8'd0;
                    temp\_debt\_matrix[row][col] <= 8'd0;
                end
            end
            // Initialize all result outputs
            result\_01 <= 8'd0; result\_02 <= 8'd0; result\_03 <= 8'd0; result\_04 <= 8'd0; result\_05 <= 8'd0; result\_06 <= 8'd0; result\_07 <= 8'd0; result\_08 <= 8'd0;
            result\_10 <= 8'd0; result\_12 <= 8'd0; result\_13 <= 8'd0; result\_14 <= 8'd0; result\_15 <= 8'd0; result\_16 <= 8'd0; result\_17 <= 8'd0; result\_18 <= 8'd0;
            result\_20 <= 8'd0; result\_21 <= 8'd0; result\_23 <= 8'd0; result\_24 <= 8'd0; result\_25 <= 8'd0; result\_26 <= 8'd0; result\_27 <= 8'd0; result\_28 <= 8'd0;
            result\_30 <= 8'd0; result\_31 <= 8'd0; result\_32 <= 8'd0; result\_34 <= 8'd0; result\_35 <= 8'd0; result\_36 <= 8'd0; result\_37 <= 8'd0; result\_38 <= 8'd0;
            result\_40 <= 8'd0; result\_41 <= 8'd0; result\_42 <= 8'd0; result\_43 <= 8'd0; result\_45 <= 8'd0; result\_46 <= 8'd0; result\_47 <= 8'd0; result\_48 <= 8'd0;
            result\_50 <= 8'd0; result\_51 <= 8'd0; result\_52 <= 8'd0; result\_53 <= 8'd0; result\_54 <= 8'd0; result\_56 <= 8'd0; result\_57 <= 8'd0; result\_58 <= 8'd0;
            result\_60 <= 8'd0; result\_61 <= 8'd0; result\_62 <= 8'd0; result\_63 <= 8'd0; result\_64 <= 8'd0; result\_65 <= 8'd0; result\_67 <= 8'd0; result\_68 <= 8'd0;
            result\_70 <= 8'd0; result\_71 <= 8'd0; result\_72 <= 8'd0; result\_73 <= 8'd0; result\_74 <= 8'd0; result\_75 <= 8'd0; result\_76 <= 8'd0; result\_78 <= 8'd0;
            result\_80 <= 8'd0; result\_81 <= 8'd0; result\_82 <= 8'd0; result\_83 <= 8'd0; result\_84 <= 8'd0; result\_85 <= 8'd0; result\_86 <= 8'd0; result\_87 <= 8'd0;
        end else begin
            state <= next\_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    input\_counter <= 4'd0;
                    p\_count <= 8'd0;
                    // Clear debt matrix
                    for (row = 0; row < 8; row = row + 1) begin
                        for (col = 0; col < 8; col = col + 1) begin
                            debt\_matrix[row][col] <= 8'd0;
                        end
                    end
                    if (start) begin
                        input\_counter <= 4'd1;
                        // Clamp overflow: if c > 255, cap at 255 (though 8-bit input already max 255)
                        if (a < 8 && b < 8) begin
                            debt\_matrix[a][b] <= (debt\_matrix[a][b] + c > 8'd255) ? 8'd255 : (debt\_matrix[a][b] + c);
                        end
                    end
                end

                INPUT: begin
                    // Process IOUs sequentially
                    input\_counter <= input\_counter + 4'd1;
                    if (input\_counter < 4'd16) begin // Up to 16 IOUs
                        if (a < 8 && b < 8) begin
                            if (debt\_matrix[a][b] + c > 8'd255) begin
                                debt\_matrix[a][b] <= 8'd255;
                            end else begin
                                debt\_matrix[a][b] <= debt\_matrix[a][b] + c;
                            end
                        end
                    end
                end

                SETTLE: begin
                    found\_cycle <= 1'b0;
                    min\_amount <= 8'd255;
                    // Copy current matrix to temp for modification
                    for (row = 0; row < 8; row = row + 1) begin
                        for (col = 0; col < 8; col = col + 1) begin
                            temp\_debt\_matrix[row][col] <= debt\_matrix[row][col];
                        end
                    end
                    // Check for cycles and find min amount
                    // Iterate through triplets (i,j,k) where i,j,k distinct
                    if (i\_idx < 8 && j\_idx < 8 && k\_idx < 8 && i\_idx != j\_idx && i\_idx != k\_idx && j\_idx != k\_idx) begin
                        if (debt\_matrix[i\_idx][j\_idx] > 8'd0 && 
                            debt\_matrix[j\_idx][k\_idx] > 8'd0 && 
                            debt\_matrix[k\_idx][i\_idx] > 8'd0) begin
                            found\_cycle <= 1'b1;
                            // Find minimum of the three
                            if (debt\_matrix[i\_idx][j\_idx] < min\_amount) min\_amount <= debt\_matrix[i\_idx][j\_idx];
                            if (debt\_matrix[j\_idx][k\_idx] < min\_amount) min\_amount <= debt\_matrix[j\_idx][k\_idx];
                            if (debt\_matrix[k\_idx][i\_idx] < min\_amount) min\_amount <= debt\_matrix[k\_idx][i\_idx];
                        end
                    end
                    // Update indices for next iteration in next cycle (simplified: fixed scan order)
                    // For synthesis, we use a simple counter approach
                    i\_idx <= i\_idx + 4'd1;
                    if (i\_idx >= 8'd7) begin
                        i\_idx <= 4'd0;
                        j\_idx <= j\_idx + 4'd1;
                        if (j\_idx >= 8'd7) begin
                            j\_idx <= 4'd0;
                            k\_idx <= k\_idx + 4'd1;
                        end
                    end
                    // If cycle found, apply subtraction in next state or here
                    // Simplified: apply immediately if cycle found
                    if (found\_cycle) begin
                        temp\_debt\_matrix[i\_idx][j\_idx] <= debt\_matrix[i\_idx][j\_idx] - min\_amount;
                        temp\_debt\_matrix[j\_idx][k\_idx] <= debt\_matrix[j\_idx][k\_idx] - min\_amount;
                        temp\_debt\_matrix[k\_idx][i\_idx] <= debt\_matrix[k\_idx][i\_idx] - min\_amount;
                        // Update main matrix
                        debt\_matrix[i\_idx][j\_idx] <= debt\_matrix[i\_idx][j\_idx] - min\_amount;
                        debt\_matrix[j\_idx][k\_idx] <= debt\_matrix[j\_idx][k\_idx] - min\_amount;
                        debt\_matrix[k\_idx][i\_idx] <= debt\_matrix[k\_idx][i\_idx] - min\_amount;
                    end
                    settle\_iter <= settle\_iter + 3'd1;
                end

                OUTPUT: begin
                    // Calculate p (count of non-zero debts)
                    p\_count <= 8'd0;
                    for (row = 0; row < 8; row = row + 1) begin
                        for (col = 0; col < 8; col = col + 1) begin
                            if (debt\_matrix[row][col] > 8'd0 && row != col) begin
                                p\_count <= p\_count + 8'd1;
                            end
                        end
                    end
                    // Assign outputs based on indices
                    // This is verbose but follows the spec for individual outputs
                    // For brevity in synthesis, we map indices to outputs
                    // Note: result\_ij where i,j are indices 0-8
                    result\_01 <= debt\_matrix[0][1]; result\_02 <= debt\_matrix[0][2]; result\_03 <= debt\_matrix[0][3]; result\_04 <= debt\_matrix[0][4];
                    result\_05 <= debt\_matrix[0][5]; result\_06 <= debt\_matrix[0][6]; result\_07 <= debt\_matrix[0][7]; result\_08 <= debt\_matrix[0][8];
                    result\_10 <= debt\_matrix[1][0]; result\_12 <= debt\_matrix[1][2]; result\_13 <= debt\_matrix[1][3]; result\_14 <= debt\_matrix[1][4];
                    result\_15 <= debt\_matrix[1][5]; result\_16 <= debt\_matrix[1][6]; result\_17 <= debt\_matrix[1][7]; result\_18 <= debt\_matrix[1][8];
                    result\_20 <= debt\_matrix[2][0]; result\_21 <= debt\_matrix[2][1]; result\_23 <= debt\_matrix[2][3]; result\_24 <= debt\_matrix[2][4];
                    result\_25 <= debt\_matrix[2][5]; result\_26 <= debt\_matrix[2][6]; result\_27 <= debt\_matrix[2][7]; result\_28 <= debt\_matrix[2][8];
                    result\_30 <= debt\_matrix[3][0]; result\_31 <= debt\_matrix[3][1]; result\_32 <= debt\_matrix[3][2]; result\_34 <= debt\_matrix[3][4];
                    result\_35 <= debt\_matrix[3][5]; result\_36 <= debt\_matrix[3][6]; result\_37 <= debt\_matrix[3][7]; result\_38 <= debt\_matrix[3][8];
                    result\_40 <= debt\_matrix[4][0]; result\_41 <= debt\_matrix[4][1]; result\_42 <= debt\_matrix[4][2]; result\_43 <= debt\_matrix[4][3];
                    result\_45 <= debt\_matrix[4][5]; result\_46 <= debt\_matrix[4][6]; result\_47 <= debt\_matrix[4][7]; result\_48 <= debt\_matrix[4][8];
                    result\_50 <= debt\_matrix[5][0]; result\_51 <= debt\_matrix[5][1]; result\_52 <= debt\_matrix[5][2]; result\_53 <= debt\_matrix[5][3];
                    result\_54 <= debt\_matrix[5][4]; result\_56 <= debt\_matrix[5][6]; result\_57 <= debt\_matrix[5][7]; result\_58 <= debt\_matrix[5][8];
                    result\_60 <= debt\_matrix[6][0]; result\_61 <= debt\_matrix[6][1]; result\_62 <= debt\_matrix[6][2]; result\_63 <= debt\_matrix[6][3];
                    result\_64 <= debt\_matrix[6][4]; result\_65 <= debt\_matrix[6][5]; result\_67 <= debt\_matrix[6][7]; result\_68 <= debt\_matrix[6][8];
                    result\_70 <= debt\_matrix[7][0]; result\_71 <= debt\_matrix[7][1]; result\_72 <= debt\_matrix[7][2]; result\_73 <= debt\_matrix[7][3];
                    result\_74 <= debt\_matrix[7][4]; result\_75 <= debt\_matrix[7][5]; result\_76 <= debt\_matrix[7][6]; result\_78 <= debt\_matrix[7][8];
                    result\_80 <= debt\_matrix[8][0]; result\_81 <= debt\_matrix[8][1]; result\_82 <= debt\_matrix[8][2]; result\_83 <= debt\_matrix[8][3];
                    result\_84 <= debt\_matrix[8][4]; result\_85 <= debt\_matrix[8][5]; result\_86 <= debt\_matrix[8][6]; result\_87 <= debt\_matrix[8][7];
                    p <= p\_count;
                end

                FINISH: begin
                    done <= 1'b1;
                    settle\_iter <= 3'd0;
                    i\_idx <= 4'd0;
                    j\_idx <= 4'd0;
                    k\_idx <= 4'd0;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next\_state = state;
        case (state)
            IDLE: if (start) next\_state = INPUT;
            INPUT: if (input\_counter >= 4'd16) next\_state = SETTLE;
            SETTLE: begin
                // Iterate up to 16 times or when no cycles found
                if (settle\_iter >= 3'd6) next\_state = OUTPUT; // Simplified: fixed 6 iterations for 8 friends
            end
            OUTPUT: next\_state = FINISH;
            FINISH: next\_state = IDLE;
            default: next\_state = IDLE;
        endcase
    end

endmodule