#include "atm90e26.h"
#include "delay_us.h"

#define SPI_TIMEOUT 5U

static ATM90E26_Status read_reg_checked(ATM90E26_Dev *dev, uint8_t reg, uint16_t *out)
{
    uint8_t tx[3] = { reg | 0x80U, 0xFFU, 0xFFU };
    uint8_t rx[3] = { 0U };

    HAL_GPIO_WritePin(dev->csPort, dev->csPin, GPIO_PIN_RESET);
    delay_us(10U);
    if (HAL_SPI_TransmitReceive(dev->hspi, tx, rx, 3U, SPI_TIMEOUT) != HAL_OK)
    {
        HAL_GPIO_WritePin(dev->csPort, dev->csPin, GPIO_PIN_SET);
        *out = 0U;
        return ATM_ERR_SPI;
    }
    delay_us(10U);
    HAL_GPIO_WritePin(dev->csPort, dev->csPin, GPIO_PIN_SET);

    *out = ((uint16_t)rx[1] << 8) | rx[2];
    return ATM_OK;
}

static ATM90E26_Status write_reg_checked(ATM90E26_Dev *dev, uint8_t reg, uint16_t val)
{
    uint8_t tx[3] = { reg & 0x7FU, (uint8_t)(val >> 8), (uint8_t)val };
    uint8_t rx[3] = { 0U };

    HAL_GPIO_WritePin(dev->csPort, dev->csPin, GPIO_PIN_RESET);
    delay_us(10U);
    if (HAL_SPI_TransmitReceive(dev->hspi, tx, rx, 3U, SPI_TIMEOUT) != HAL_OK)
    {
        HAL_GPIO_WritePin(dev->csPort, dev->csPin, GPIO_PIN_SET);
        return ATM_ERR_SPI;
    }
    delay_us(10U);
    HAL_GPIO_WritePin(dev->csPort, dev->csPin, GPIO_PIN_SET);

    return ATM_OK;
}

uint16_t ATM90E26_ReadReg(ATM90E26_Dev *dev, uint8_t reg)
{
    uint16_t value = 0U;
    (void)read_reg_checked(dev, reg, &value);
    return value;
}

void ATM90E26_WriteReg(ATM90E26_Dev *dev, uint8_t reg, uint16_t val)
{
    (void)write_reg_checked(dev, reg, val);
}

static uint16_t calc_checksum(const uint16_t *regs, uint8_t count)
{
    uint8_t sum = 0U;
    uint8_t xorv = 0U;
    uint8_t i;

    for (i = 0U; i < count; i++)
    {
        uint8_t hi = (uint8_t)(regs[i] >> 8);
        uint8_t lo = (uint8_t)regs[i];
        sum = (uint8_t)(sum + hi + lo);
        xorv ^= hi;
        xorv ^= lo;
    }

    return ((uint16_t)xorv << 8) | sum;
}

static uint16_t calc_cs_one(const ATM90E26_CalConfig *c)
{
    uint16_t regs[11] = {
        c->plconstH, c->plconstL, c->lgain, c->lphi,
        c->ngain, c->nphi, c->pStartTh, c->pNolTh,
        c->qStartTh, c->qNolTh, c->mmode
    };
    return calc_checksum(regs, 11U);
}

static uint16_t calc_cs_two(const ATM90E26_CalConfig *c)
{
    uint16_t regs[10] = {
        c->ugain, c->igainL, c->igainN,
        c->uoffset, c->ioffsetL, c->ioffsetN,
        c->poffsetL, c->qoffsetL, c->poffsetN, c->qoffsetN
    };
    return calc_checksum(regs, 10U);
}

static int16_t decode_sign_magnitude(uint16_t raw)
{
    int32_t magnitude = (int32_t)(raw & 0x7FFFU);
    return (raw & 0x8000U) ? (int16_t)(-magnitude) : (int16_t)magnitude;
}

ATM90E26_CalConfig ATM90E26_DefaultCal(void)
{
    ATM90E26_CalConfig c = {
        .plconstH = 0x00B9,
        .plconstL = 0xC1F3,
        .lgain    = 0x1D39,
        .lphi     = 0x0000,
        .ngain    = 0x0000,
        .nphi     = 0x0000,
        .pStartTh = 0x08BD,
        .pNolTh   = 0x0000,
        .qStartTh = 0x0AEC,
        .qNolTh   = 0x0000,
        .mmode    = 0x9422,
        .ugain    = 0x6720,
        .igainL   = 0x7A13,
        .igainN   = 0x7530,
        .uoffset  = 0x0000,
        .ioffsetL = 0x0000,
        .ioffsetN = 0x0000,
        .poffsetL = 0x0000,
        .qoffsetL = 0x0000,
        .poffsetN = 0x0000,
        .qoffsetN = 0x0000
    };
    return c;
}

ATM90E26_Status ATM90E26_Init(ATM90E26_Dev *dev)
{
    ATM90E26_Status st;
    uint16_t reg_value = 0U;
    uint16_t cs1;
    uint16_t cs2;

    dev->initialized = 0U;

    HAL_GPIO_WritePin(dev->csPort, dev->csPin, GPIO_PIN_SET);
    HAL_Delay(100U);

    st = write_reg_checked(dev, ATM_REG_SOFT_RESET, 0x789AU);
    if (st != ATM_OK)
        return st;
    HAL_Delay(100U);

    st = write_reg_checked(dev, ATM_REG_FUNC_EN, 0x0030U);
    if (st != ATM_OK)
        return st;
    HAL_Delay(10U);

    st = read_reg_checked(dev, ATM_REG_LAST_DATA, &reg_value);
    if (st != ATM_OK)
        return st;
    if (reg_value != 0x0030U)
        return ATM_ERR_COMM_VERIFY;

    st = write_reg_checked(dev, ATM_REG_SAG_TH, 0x1F2FU);
    if (st != ATM_OK)
        return st;

    cs1 = calc_cs_one(&dev->cal);
    st = write_reg_checked(dev, ATM_REG_CAL_START, 0x5678U);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_PL_CONST_H, dev->cal.plconstH);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_PL_CONST_L, dev->cal.plconstL);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_L_GAIN, dev->cal.lgain);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_L_PHI, dev->cal.lphi);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_N_GAIN, dev->cal.ngain);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_N_PHI, dev->cal.nphi);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_P_START_TH, dev->cal.pStartTh);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_P_NOL_TH, dev->cal.pNolTh);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_Q_START_TH, dev->cal.qStartTh);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_Q_NOL_TH, dev->cal.qNolTh);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_M_MODE, dev->cal.mmode);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_CS_ONE, cs1);
    if (st != ATM_OK) return st;

    cs2 = calc_cs_two(&dev->cal);
    st = write_reg_checked(dev, ATM_REG_ADJ_START, 0x5678U);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_U_GAIN, dev->cal.ugain);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_I_GAIN_L, dev->cal.igainL);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_I_GAIN_N, dev->cal.igainN);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_U_OFFSET, dev->cal.uoffset);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_I_OFFSET_L, dev->cal.ioffsetL);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_I_OFFSET_N, dev->cal.ioffsetN);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_P_OFFSET_L, dev->cal.poffsetL);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_Q_OFFSET_L, dev->cal.qoffsetL);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_P_OFFSET_N, dev->cal.poffsetN);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_Q_OFFSET_N, dev->cal.qoffsetN);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_CS_TWO, cs2);
    if (st != ATM_OK) return st;

    st = write_reg_checked(dev, ATM_REG_CAL_START, 0x8765U);
    if (st != ATM_OK) return st;
    st = write_reg_checked(dev, ATM_REG_ADJ_START, 0x8765U);
    if (st != ATM_OK) return st;
    HAL_Delay(10U);

    st = read_reg_checked(dev, ATM_REG_SYS_STATUS, &reg_value);
    if (st != ATM_OK)
        return st;
    dev->lastSysStatus = reg_value;

    if ((reg_value & ATM_SYS_CAL_ERR) != 0U)
        return ATM_ERR_CS1_CHECKSUM;
    if ((reg_value & ATM_SYS_ADJ_ERR) != 0U)
        return ATM_ERR_CS2_CHECKSUM;

    dev->initialized = 1U;
    return ATM_OK;
}

uint16_t ATM90E26_GetSysStatus(ATM90E26_Dev *dev)
{
    uint16_t status = 0U;

    if (read_reg_checked(dev, ATM_REG_SYS_STATUS, &status) == ATM_OK)
        dev->lastSysStatus = status;

    return dev->lastSysStatus;
}

uint16_t ATM90E26_GetMeterStatus(ATM90E26_Dev *dev)
{
    uint16_t status = 0U;
    if (read_reg_checked(dev, ATM_REG_EN_STATUS, &status) != ATM_OK)
        return 0U;
    return status;
}

ATM90E26_Status ATM90E26_ReadAll(ATM90E26_Dev *dev, ATM90E26_Meas *m)
{
    ATM90E26_Status st;
    uint16_t raw = 0U;

    if (dev->initialized == 0U)
        return ATM_ERR_NOT_INIT;

    st = read_reg_checked(dev, ATM_REG_URMS, &m->voltage);
    if (st != ATM_OK) return st;
    st = read_reg_checked(dev, ATM_REG_IRMS, &m->current);
    if (st != ATM_OK) return st;
    st = read_reg_checked(dev, ATM_REG_IRMS_TWO, &m->currentN);
    if (st != ATM_OK) return st;
    st = read_reg_checked(dev, ATM_REG_PMEAN, &raw);
    if (st != ATM_OK) return st;
    m->activePower = (int16_t)raw;
    st = read_reg_checked(dev, ATM_REG_QMEAN, &raw);
    if (st != ATM_OK) return st;
    m->reactivePower = (int16_t)raw;
    st = read_reg_checked(dev, ATM_REG_S_MEAN, &raw);
    if (st != ATM_OK) return st;
    m->apparentPower = raw;
    st = read_reg_checked(dev, ATM_REG_FREQ, &m->frequency);
    if (st != ATM_OK) return st;
    st = read_reg_checked(dev, ATM_REG_POWER_F, &raw);
    if (st != ATM_OK) return st;
    m->powerFactor = decode_sign_magnitude(raw);
    st = read_reg_checked(dev, ATM_REG_P_ANGLE, &raw);
    if (st != ATM_OK) return st;
    m->phaseAngle = decode_sign_magnitude(raw);

    if ((m->voltage == 0U) && (m->frequency == 0U))
        return ATM_ERR_COMM_VERIFY;

    st = read_reg_checked(dev, ATM_REG_AP_ENERGY, &m->importEnergy);
    if (st != ATM_OK) return st;
    st = read_reg_checked(dev, ATM_REG_AN_ENERGY, &m->exportEnergy);
    if (st != ATM_OK) return st;

    dev->totalImportEnergy += m->importEnergy;
    dev->totalExportEnergy += m->exportEnergy;

    st = read_reg_checked(dev, ATM_REG_SYS_STATUS, &dev->lastSysStatus);
    if (st != ATM_OK) return st;

    return ATM_OK;
}
